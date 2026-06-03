#include "starlingclient.h"
#include "tokenstore.h"

#include <QDate>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <functional>
#include <algorithm>
#include <QBuffer>
#include <QSettings>
#include <QCryptographicHash>
#include <QUuid>
#include <QtMath>
#include <QLocale>
#include <QtGlobal>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/bio.h>
#include <openssl/err.h>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMimeType>

static const char *BASE_URL = "https://api.starlingbank.com";

StarlingClient::StarlingClient(QObject *parent)
    : QObject(parent)
{
    setLocked(true);
    setStatus(QStringLiteral("Authentication required."));

    QSettings settings;
    m_autoLockMinutes = settings.value(QStringLiteral("security/autoLockMinutes"), 2).toInt();
    m_lockOnBackground = settings.value(QStringLiteral("security/lockOnBackground"), true).toBool();
    m_pinHash = settings.value(QStringLiteral("security/pinHash")).toString();
    m_pinSalt = settings.value(QStringLiteral("security/pinSalt")).toString();

    m_relockTimer.setSingleShot(true);
    m_relockTimer.setInterval(m_autoLockMinutes * 60 * 1000);
    connect(&m_relockTimer, &QTimer::timeout, this, [this]() {
        lock();
    });

    setOnline(m_networkConfigManager.isOnline());

    connect(&m_networkConfigManager, &QNetworkConfigurationManager::onlineStateChanged,
            this, [this](bool isOnline) {
        const bool wasOnline = m_online;
        setOnline(isOnline);

        if (!isOnline) {
            setStatus(QStringLiteral("No internet connection."));
            return;
        }

        if (!wasOnline
                && !m_locked
                && !m_token.trimmed().isEmpty()
                && !m_initializing
                && !m_busy) {
            refreshAll(m_startupDaysBack > 0 ? m_startupDaysBack : 14);
        }
    });
}

bool StarlingClient::localFileExists(const QString &filePath) const
{
    const QFileInfo info(filePath.trimmed());
    return info.exists() && info.isFile();
}

// Payee Account
QString StarlingClient::payeeImagePath() const
{
    return m_payeeImagePath;
}

bool StarlingClient::payeeImageAvailable() const
{
    return m_payeeImageAvailable;
}

void StarlingClient::refreshPayeeImage(const QString &payeeUid)
{
    const QString trimmedPayeeUid = payeeUid.trimmed();

    if (trimmedPayeeUid.isEmpty()) {
        m_payeeImageAvailable = false;
        m_payeeImagePath.clear();
        emit payeeImageChanged();
        setStatus(QStringLiteral("Payee ID is missing."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/payees/%1/image")
            .arg(trimmedPayeeUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    setStatus(QStringLiteral("Loading payee image..."));
    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep, trimmedPayeeUid]() {
        const QByteArray body = rep->readAll();
        const int httpStatus =
                rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (rep->error() != QNetworkReply::NoError) {
            m_payeeImageAvailable = false;
            m_payeeImagePath.clear();
            emit payeeImageChanged();

            if (httpStatus == 404) {
                setStatus(QStringLiteral("No payee image found."));
            } else {
                qWarning() << "refreshPayeeImage failed url=" << rep->url()
                           << "status=" << httpStatus
                           << "qtError=" << rep->errorString()
                           << "body=" << QString::fromUtf8(body);

                setStatus(QStringLiteral("Payee image unavailable."));
            }

            rep->deleteLater();
            endRequest();
            return;
        }

        const QString cacheRoot =
                QStandardPaths::writableLocation(QStandardPaths::CacheLocation);

        QDir dir(cacheRoot);
        if (!dir.exists())
            dir.mkpath(QStringLiteral("."));

        QString extension = QStringLiteral(".jpg");
        const QString contentType =
                rep->header(QNetworkRequest::ContentTypeHeader).toString();

        if (contentType.contains(QStringLiteral("png")))
            extension = QStringLiteral(".png");
        else if (contentType.contains(QStringLiteral("webp")))
            extension = QStringLiteral(".webp");
        else if (contentType.contains(QStringLiteral("jpeg")) || contentType.contains(QStringLiteral("jpg")))
            extension = QStringLiteral(".jpg");

        const QString filePath =
                dir.filePath(QStringLiteral("payee-image-%1%2")
                             .arg(trimmedPayeeUid.left(8))
                             .arg(extension));

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            m_payeeImageAvailable = false;
            m_payeeImagePath.clear();
            emit payeeImageChanged();

            setStatus(QStringLiteral("Could not save payee image."));
            rep->deleteLater();
            endRequest();
            return;
        }

        file.write(body);
        file.close();

        m_payeeImagePath = filePath;
        m_payeeImageAvailable = true;
        emit payeeImageChanged();

        setStatus(QStringLiteral("Payee image loaded."));

        rep->deleteLater();
        endRequest();
    });
}

QVariantList StarlingClient::payeeAccountScheduledPayments() const
{
    return m_payeeAccountScheduledPayments;
}

QVariantList StarlingClient::payeeAccountPayments() const
{
    return m_payeeAccountPayments;
}

void StarlingClient::refreshPayeeAccountScheduledPayments(const QString &payeeUid,
                                                          const QString &payeeAccountUid)
{
    const QString trimmedPayeeUid = payeeUid.trimmed();
    const QString trimmedAccountUid = payeeAccountUid.trimmed();

    if (trimmedPayeeUid.isEmpty() || trimmedAccountUid.isEmpty()) {
        setStatus(QStringLiteral("Payee account details are missing."));
        return;
    }

    m_payeeAccountScheduledPayments.clear();
    emit payeeAccountScheduledPaymentsChanged();

    const QString path =
            QStringLiteral("/api/v2/payees/%1/account/%2/scheduled-payments")
            .arg(trimmedPayeeUid)
            .arg(trimmedAccountUid);

    setStatus(QStringLiteral("Loading scheduled payments..."));

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("scheduledPayments")).toArray();

        if (items.isEmpty())
            items = root.value(QStringLiteral("payments")).toArray();

        if (items.isEmpty())
            items = root.value(QStringLiteral("paymentOrders")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

//            qWarning() << "payee scheduled payment item="
//                       << QJsonDocument(item).toJson(QJsonDocument::Compact);

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QJsonObject paymentAmount = item.value(QStringLiteral("paymentAmount")).toObject();
            const QJsonObject nextPaymentAmount = item.value(QStringLiteral("nextPaymentAmount")).toObject();

            const QJsonObject money = !nextPaymentAmount.isEmpty()
                    ? nextPaymentAmount
                    : (!amount.isEmpty() ? amount : paymentAmount);

            const QString currency =
                    money.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor =
                    money.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            QVariantMap row;

            row.insert(QStringLiteral("paymentOrderUid"),
                       item.value(QStringLiteral("paymentOrderUid")).toString(
                           item.value(QStringLiteral("uid")).toString()));

            const QString nextPaymentDate =
                    item.value(QStringLiteral("nextDate")).toString(
                        item.value(QStringLiteral("paymentDate")).toString(
                            item.value(QStringLiteral("scheduledDate")).toString(
                                item.value(QStringLiteral("date")).toString())));

            if (nextPaymentDate.isEmpty())
                continue;

            row.insert(QStringLiteral("date"), nextPaymentDate);

            row.insert(QStringLiteral("createdAt"),
                       formatIsoDateTime(item.value(QStringLiteral("createdAt")).toString()));

            row.insert(QStringLiteral("amount"),
                       minor > 0 ? formatMinorUnits(minor, currency) : QString());

            row.insert(QStringLiteral("reference"),
                       item.value(QStringLiteral("reference")).toString());

            row.insert(QStringLiteral("status"),
                       item.value(QStringLiteral("status")).toString());

            const QJsonObject recurrence =
                    item.value(QStringLiteral("recurrenceRule")).toObject();

            row.insert(QStringLiteral("frequency"),
                       recurrence.value(QStringLiteral("frequency")).toString(
                           item.value(QStringLiteral("frequency")).toString()));

            row.insert(QStringLiteral("interval"),
                       recurrence.value(QStringLiteral("interval")).toVariant().toString());

            row.insert(QStringLiteral("count"),
                       recurrence.value(QStringLiteral("count")).toVariant().toString());

            row.insert(QStringLiteral("untilDate"),
                       recurrence.value(QStringLiteral("untilDate")).toString());

            row.insert(QStringLiteral("paymentType"),
                       item.value(QStringLiteral("paymentType")).toString());

            row.insert(QStringLiteral("spendingCategory"),
                       item.value(QStringLiteral("spendingCategory")).toString());

            rows.append(row);
        }

        m_payeeAccountScheduledPayments = rows;
        emit payeeAccountScheduledPaymentsChanged();

        setStatus(rows.isEmpty()
                  ? QStringLiteral("No scheduled payments found.")
                  : QStringLiteral("Loaded %1 scheduled payment(s).").arg(rows.size()));
    });
}

void StarlingClient::refreshPayeeAccountPayments(const QString &payeeUid,
                                                 const QString &payeeAccountUid)
{
    const QString trimmedPayeeUid = payeeUid.trimmed();
    const QString trimmedAccountUid = payeeAccountUid.trimmed();

    if (trimmedPayeeUid.isEmpty() || trimmedAccountUid.isEmpty()) {
        setStatus(QStringLiteral("Payee account details are missing."));
        return;
    }

    m_payeeAccountPayments.clear();
    emit payeeAccountPaymentsChanged();

    const QString path =
            QStringLiteral("/api/v2/payees/%1/account/%2/payments")
            .arg(trimmedPayeeUid)
            .arg(trimmedAccountUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("since"),
                       QDate::currentDate().addYears(-1).toString(Qt::ISODate));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    setStatus(QStringLiteral("Loading payee payment history..."));
    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep]() {
        const QByteArray body = rep->readAll();
        const int httpStatus =
                rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "refreshPayeeAccountPayments failed url=" << rep->url()
                       << "status=" << httpStatus
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(body);

            m_payeeAccountPayments.clear();
            emit payeeAccountPaymentsChanged();

            setStatus(QStringLiteral("Payee payment history unavailable."));
            rep->deleteLater();
            endRequest();
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("payments")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("paymentOrders")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QJsonObject amount = item.value(QStringLiteral("paymentAmount")).toObject();
            const QString currency =
                    amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor =
                    amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            QVariantMap row;
            row.insert(QStringLiteral("paymentUid"),
                       item.value(QStringLiteral("paymentUid")).toString(
                           item.value(QStringLiteral("uid")).toString()));
            row.insert(QStringLiteral("date"),
                       formatIsoDateTime(item.value(QStringLiteral("createdAt")).toString(
                           item.value(QStringLiteral("paymentDate")).toString(
                               item.value(QStringLiteral("date")).toString()))));
            row.insert(QStringLiteral("amount"),
                       minor > 0 ? formatMinorUnits(minor, currency) : QString());
            row.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());
            row.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());
            row.insert(QStringLiteral("spendingCategory"), item.value(QStringLiteral("spendingCategory")).toString());
            row.insert(QStringLiteral("rowType"), QStringLiteral("transaction"));
            row.insert(QStringLiteral("title"), item.value(QStringLiteral("reference")).toString(QStringLiteral("Payment")));
            row.insert(QStringLiteral("direction"), QStringLiteral("OUT"));
            row.insert(QStringLiteral("currency"), currency);
            row.insert(QStringLiteral("amountValue"), static_cast<qint64>(minor));
            row.insert(QStringLiteral("category"), item.value(QStringLiteral("spendingCategory")).toString());
            row.insert(QStringLiteral("dateRaw"), item.value(QStringLiteral("createdAt")).toString());
            row.insert(QStringLiteral("feedItemUid"), item.value(QStringLiteral("feedItemUid")).toString());
            row.insert(QStringLiteral("userNote"), item.value(QStringLiteral("userNote")).toString());
            row.insert(QStringLiteral("paymentUid"), item.value(QStringLiteral("paymentUid")).toString());

            rows.append(row);
        }

        m_payeeAccountPayments = rows;
        emit payeeAccountPaymentsChanged();

        setStatus(rows.isEmpty()
                  ? QStringLiteral("No payee payments found.")
                  : QStringLiteral("Loaded %1 payee payment(s).").arg(rows.size()));

        rep->deleteLater();
        endRequest();
    });
}

// Profile image
bool StarlingClient::isSupportedProfileImageFile(const QString &filePath) const
{
    QFileInfo info(filePath.trimmed());
    if (!info.exists() || !info.isFile())
        return false;

    QMimeDatabase mimeDb;
    const QMimeType mime = mimeDb.mimeTypeForFile(info);
    const QString mimeName = mime.isValid()
            ? mime.name()
            : QStringLiteral("application/octet-stream");

    return mimeName.startsWith(QStringLiteral("image/"));
}

QString StarlingClient::profileImagePath() const
{
    return m_profileImagePath;
}

bool StarlingClient::profileImageAvailable() const
{
    return m_profileImageAvailable;
}

void StarlingClient::refreshProfileImage()
{
    const QString accountHolderUid =
            m_accountHolderBasic.value(QStringLiteral("accountHolderUid")).toString();

    if (accountHolderUid.isEmpty()) {
        setStatus(QStringLiteral("Account holder ID is missing."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/account-holder/%1/profile-image")
            .arg(accountHolderUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    setStatus(QStringLiteral("Loading profile image..."));
    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep, accountHolderUid]() {
        const QByteArray body = rep->readAll();
        const int httpStatus =
                rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (rep->error() != QNetworkReply::NoError) {
            m_profileImageAvailable = false;
            m_profileImagePath.clear();
            emit profileImageChanged();

            if (httpStatus == 404) {
                setStatus(QStringLiteral("No profile image found."));
            } else {
                qWarning() << "refreshProfileImage failed url=" << rep->url()
                           << "status=" << httpStatus
                           << "qtError=" << rep->errorString()
                           << "body=" << QString::fromUtf8(body);

                setStatus(QStringLiteral("Profile image unavailable."));
            }

            rep->deleteLater();
            endRequest();
            return;
        }

        const QString cacheRoot =
                QStandardPaths::writableLocation(QStandardPaths::CacheLocation);

        QDir dir(cacheRoot);
        if (!dir.exists())
            dir.mkpath(QStringLiteral("."));

        QString extension = QStringLiteral(".jpg");
        const QString contentType =
                rep->header(QNetworkRequest::ContentTypeHeader).toString();

        if (contentType.contains(QStringLiteral("png")))
            extension = QStringLiteral(".png");
        else if (contentType.contains(QStringLiteral("webp")))
            extension = QStringLiteral(".webp");

        const QString filePath =
                dir.filePath(QStringLiteral("profile-image-%1%2")
                             .arg(accountHolderUid.left(8))
                             .arg(extension));

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            m_profileImageAvailable = false;
            m_profileImagePath.clear();
            emit profileImageChanged();

            setStatus(QStringLiteral("Could not save profile image."));
            rep->deleteLater();
            endRequest();
            return;
        }

        file.write(body);
        file.close();

        m_profileImagePath = filePath;
        m_profileImageAvailable = true;
        emit profileImageChanged();

        setStatus(QStringLiteral("Profile image loaded."));

        rep->deleteLater();
        endRequest();
    });
}

void StarlingClient::updateProfileImage(const QString &filePath)
{
    const QString accountHolderUid =
            m_accountHolderBasic.value(QStringLiteral("accountHolderUid")).toString();

    if (accountHolderUid.isEmpty()) {
        setStatus(QStringLiteral("Account holder ID is missing."));
        return;
    }

    const QString trimmedFilePath = filePath.trimmed();

    QFileInfo info(trimmedFilePath);
    if (!info.exists() || !info.isFile()) {
        setStatus(QStringLiteral("Profile image file not found."));
        return;
    }

    QMimeDatabase mimeDb;
    const QMimeType mime = mimeDb.mimeTypeForFile(info);
    const QString mimeName = mime.isValid()
            ? mime.name()
            : QStringLiteral("application/octet-stream");

    if (!mimeName.startsWith(QStringLiteral("image/"))) {
        setStatus(QStringLiteral("Only image files can be used as a profile image."));
        return;
    }

    QFile file(info.absoluteFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        setStatus(QStringLiteral("Could not open profile image."));
        return;
    }

    const QByteArray body = file.readAll();
    file.close();

    const QString path =
            QStringLiteral("/api/v2/account-holder/%1/profile-image")
            .arg(accountHolderUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(mimeName));

    setStatus(QStringLiteral("Updating profile image..."));
    beginRequest();

    QNetworkReply *rep = m_nam.put(req, body);

    connect(rep, &QNetworkReply::finished, this, [this, rep]() {
        const QByteArray responseBody = rep->readAll();
        const int httpStatus =
                rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "updateProfileImage failed url=" << rep->url()
                       << "status=" << httpStatus
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(responseBody);

            setStatus(QStringLiteral("Profile image update failed: %1").arg(rep->errorString()));
            rep->deleteLater();
            endRequest();
            return;
        }

        setStatus(QStringLiteral("Profile image updated."));
        refreshProfileImage();
        touchLastUpdated();
        emit profileImageUpdated();

        rep->deleteLater();
        endRequest();
    });
}

void StarlingClient::deleteProfileImage()
{
    const QString accountHolderUid =
            m_accountHolderBasic.value(QStringLiteral("accountHolderUid")).toString();

    if (accountHolderUid.isEmpty()) {
        setStatus(QStringLiteral("Account holder ID is missing."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/account-holder/%1/profile-image")
            .arg(accountHolderUid);

    setStatus(QStringLiteral("Deleting profile image..."));

    sendDeleteWithToken(path, m_token, [this](const QByteArray &) {
        m_profileImageAvailable = false;
        m_profileImagePath.clear();
        emit profileImageChanged();

        setStatus(QStringLiteral("Profile image deleted."));
        touchLastUpdated();
        emit profileImageDeleted();
    });
}

// Address
QVariantMap StarlingClient::currentAddress() const
{
    return m_currentAddress;
}

void StarlingClient::updateAccountHolderAddress(const QString &line1,
                                                const QString &line2,
                                                const QString &line3,
                                                const QString &postTown,
                                                const QString &postCode,
                                                const QString &countryCode,
                                                const QString &fromDate)
{
    const QString trimmedLine1 = line1.trimmed();
    const QString trimmedPostTown = postTown.trimmed();
    const QString trimmedPostCode = postCode.trimmed();
    const QString trimmedCountryCode = countryCode.trimmed().toUpper();
    const QString trimmedFromDate = fromDate.trimmed();

    if (trimmedLine1.isEmpty()) {
        setStatus(QStringLiteral("Address line 1 is missing."));
        return;
    }

    if (trimmedPostTown.isEmpty()) {
        setStatus(QStringLiteral("Town/city is missing."));
        return;
    }

    if (trimmedPostCode.isEmpty()) {
        setStatus(QStringLiteral("Postcode is missing."));
        return;
    }

    if (trimmedCountryCode.length() != 2) {
        setStatus(QStringLiteral("Country code must be two letters."));
        return;
    }

    const QDate parsedFromDate = QDate::fromString(trimmedFromDate, Qt::ISODate);
    if (!parsedFromDate.isValid()) {
        setStatus(QStringLiteral("Invalid address start date. Use YYYY-MM-DD."));
        return;
    }

    QJsonObject body;
    body.insert(QStringLiteral("line1"), trimmedLine1);
    body.insert(QStringLiteral("line2"), line2.trimmed());
    body.insert(QStringLiteral("line3"), line3.trimmed());
    body.insert(QStringLiteral("postTown"), trimmedPostTown);
    body.insert(QStringLiteral("postCode"), trimmedPostCode);
    body.insert(QStringLiteral("countryCode"), trimmedCountryCode);
    body.insert(QStringLiteral("from"), trimmedFromDate);

    setStatus(QStringLiteral("Updating address..."));

    sendJsonWithToken(QStringLiteral("/api/v2/addresses"),
                      QStringLiteral("POST"),
                      body,
                      m_token,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Address updated."));
        refreshAll(m_startupDaysBack);
        touchLastUpdated();
        emit accountHolderAddressUpdated();
    }, true);
}

// Account holder
QVariantMap StarlingClient::accountHolderBasic() const
{
    return m_accountHolderBasic;
}

void StarlingClient::refreshAccountHolderBasic()
{
    setStatus(QStringLiteral("Loading account holder details..."));

    getJson(QStringLiteral("/api/v2/account-holder"),
            [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QVariantMap data;
        data.insert(QStringLiteral("accountHolderUid"),
                    root.value(QStringLiteral("accountHolderUid")).toString());
        data.insert(QStringLiteral("accountHolderType"),
                    root.value(QStringLiteral("accountHolderType")).toString());
        data.insert(QStringLiteral("accountHolderState"),
                    root.value(QStringLiteral("accountHolderState")).toString());

        m_accountHolderBasic = data;
        emit accountHolderBasicChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Account holder details loaded."));
    });
}

void StarlingClient::updateAccountHolderEmail(const QString &email)
{
    const QString trimmedEmail = email.trimmed();

    if (trimmedEmail.isEmpty()) {
        setStatus(QStringLiteral("Email address is missing."));
        return;
    }

    if (!trimmedEmail.contains(QLatin1Char('@')) || !trimmedEmail.contains(QLatin1Char('.'))) {
        setStatus(QStringLiteral("Invalid email address."));
        return;
    }

    QJsonObject body;
    body.insert(QStringLiteral("email"), trimmedEmail);

    setStatus(QStringLiteral("Updating email address..."));

    sendJsonWithToken(QStringLiteral("/api/v2/account-holder/individual/email"),
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this, trimmedEmail](const QByteArray &) {
        m_email = trimmedEmail;
        emit accountChanged();

        setStatus(QStringLiteral("Email address updated."));
        touchLastUpdated();
        emit accountHolderEmailUpdated(trimmedEmail);
    }, true);
}

// Transactions
QString StarlingClient::lastAttachmentPath() const
{
    return m_lastAttachmentPath;
}

void StarlingClient::clearLastAttachmentPath()
{
    if (m_lastAttachmentPath.isEmpty())
        return;

    m_lastAttachmentPath.clear();
    emit lastAttachmentPathChanged();
}

void StarlingClient::uploadTransactionAttachment(const QString &feedItemUid,
                                                 const QString &filePath)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedFeedItemUid = feedItemUid.trimmed();
    const QString trimmedFilePath = filePath.trimmed();

    if (trimmedFeedItemUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    QFileInfo info(trimmedFilePath);
    if (!info.exists() || !info.isFile()) {
        setStatus(QStringLiteral("Attachment file not found."));
        return;
    }

    QFile *file = new QFile(info.absoluteFilePath(), this);
    if (!file->open(QIODevice::ReadOnly)) {
        file->deleteLater();
        setStatus(QStringLiteral("Could not open attachment file."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/attachments")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedFeedItemUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    QMimeDatabase mimeDb;
    const QMimeType mime = mimeDb.mimeTypeForFile(info);
    const QString mimeName = mime.isValid()
            ? mime.name()
            : QStringLiteral("application/octet-stream");

    if (!(mimeName.startsWith(QStringLiteral("image/"))
            || mimeName == QStringLiteral("application/pdf"))) {
        file->deleteLater();
        setStatus(QStringLiteral("Only images and PDF files can be uploaded."));
        return;
    }

    const QByteArray body = file->readAll();
    file->deleteLater();

    req.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(mimeName));


    setStatus(QStringLiteral("Uploading attachment..."));
    beginRequest();

    QNetworkReply *rep = m_nam.post(req, body);

    connect(rep, &QNetworkReply::finished, this, [this, rep, trimmedFeedItemUid]() {
        const QByteArray body = rep->readAll();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "uploadTransactionAttachment failed url=" << rep->url()
                       << "status=" << rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(body);

            setStatus(QStringLiteral("Attachment upload failed: %1").arg(rep->errorString()));
            rep->deleteLater();
            endRequest();
            return;
        }

        setStatus(QStringLiteral("Attachment uploaded."));
        refreshTransactionAttachments(trimmedFeedItemUid);
        emit transactionAttachmentUploaded(trimmedFeedItemUid);
        touchLastUpdated();

        rep->deleteLater();
        endRequest();
    });
}

void StarlingClient::downloadTransactionAttachment(const QString &feedItemUid,
                                                   const QString &attachmentUid,
                                                   const QString &name)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedFeedItemUid = feedItemUid.trimmed();
    const QString trimmedAttachmentUid = attachmentUid.trimmed();

    if (trimmedFeedItemUid.isEmpty() || trimmedAttachmentUid.isEmpty()) {
        setStatus(QStringLiteral("Attachment details are missing."));
        return;
    }

    QString safeName = name.trimmed();
    if (safeName.isEmpty())
        safeName = QStringLiteral("attachment");

    safeName.replace(QStringLiteral("/"), QStringLiteral("_"));
    safeName.replace(QStringLiteral("\\"), QStringLiteral("_"));

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/attachments/%4")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedFeedItemUid)
            .arg(trimmedAttachmentUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    setStatus(QStringLiteral("Downloading attachment..."));
    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep, safeName, trimmedFeedItemUid, trimmedAttachmentUid]() {
        const QByteArray body = rep->readAll();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "downloadTransactionAttachment failed url=" << rep->url()
                       << "status=" << rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(body);

            setStatus(QStringLiteral("Attachment download failed: %1").arg(rep->errorString()));
            rep->deleteLater();
            endRequest();
            return;
        }

        const QString docsRoot = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        QDir dir(docsRoot + QStringLiteral("/Starling Attachments"));

        if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
            setStatus(QStringLiteral("Could not create attachment folder."));
            rep->deleteLater();
            endRequest();
            return;
        }

        QString finalName = QStringLiteral("%1-%2-%3")
                .arg(trimmedFeedItemUid.left(8))
                .arg(trimmedAttachmentUid.left(8))
                .arg(safeName);

        if (!finalName.contains(QLatin1Char('.'))) {
            const QString contentType = rep->header(QNetworkRequest::ContentTypeHeader).toString();

            if (contentType.contains(QStringLiteral("png")))
                finalName += QStringLiteral(".png");
            else if (contentType.contains(QStringLiteral("jpeg")) || contentType.contains(QStringLiteral("jpg")))
                finalName += QStringLiteral(".jpg");
            else if (contentType.contains(QStringLiteral("pdf")))
                finalName += QStringLiteral(".pdf");
        }

        const QString filePath = dir.filePath(finalName);

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            setStatus(QStringLiteral("Could not save attachment."));
            rep->deleteLater();
            endRequest();
            return;
        }

        file.write(body);
        file.close();

        m_lastAttachmentPath = filePath;
        emit lastAttachmentPathChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Attachment saved: %1").arg(filePath));

        rep->deleteLater();
        endRequest();
    });
}

QVariantMap StarlingClient::transactionMastercardDetails() const
{
    return m_transactionMastercardDetails;
}

void StarlingClient::refreshTransactionMastercardDetails(const QString &feedItemUid)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    m_transactionMastercardDetails.clear();
    emit transactionMastercardDetailsChanged();

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/mastercard")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Loading card transaction details..."));

    getJson(path, [this, trimmedUid](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QVariantMap details;
        details.insert(QStringLiteral("feedItemUid"), trimmedUid);
        details.insert(QStringLiteral("merchantName"), root.value(QStringLiteral("merchantName")).toString());
        details.insert(QStringLiteral("merchantCategoryCode"), root.value(QStringLiteral("merchantCategoryCode")).toString());
        details.insert(QStringLiteral("merchantCategory"), root.value(QStringLiteral("merchantCategory")).toString());
        details.insert(QStringLiteral("merchantCountry"), root.value(QStringLiteral("merchantCountry")).toString());
        details.insert(QStringLiteral("merchantCity"), root.value(QStringLiteral("merchantCity")).toString());
        details.insert(QStringLiteral("cardLastFour"), root.value(QStringLiteral("cardLastFour")).toString());
        details.insert(QStringLiteral("cardPresent"), root.value(QStringLiteral("cardPresent")).toBool());
        details.insert(QStringLiteral("wallet"), root.value(QStringLiteral("wallet")).toString());
        details.insert(QStringLiteral("posEntryMode"), root.value(QStringLiteral("posEntryMode")).toString());

        m_transactionMastercardDetails = details;
        emit transactionMastercardDetailsChanged();

        setStatus(QStringLiteral("Card transaction details loaded."));
    });
}

QVariantList StarlingClient::transactionReceipts() const
{
    return m_transactionReceipts;
}

void StarlingClient::refreshTransactionReceipts(const QString &feedItemUid)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    m_transactionReceipts.clear();
    emit transactionReceiptsChanged();

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/receipts")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Loading transaction receipts..."));

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("receipts")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("feedItemReceipts")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("receiptUid"),
                       item.value(QStringLiteral("receiptUid")).toString(
                           item.value(QStringLiteral("uid")).toString()));
            row.insert(QStringLiteral("name"),
                       item.value(QStringLiteral("name")).toString(
                           item.value(QStringLiteral("merchantName")).toString()));
            row.insert(QStringLiteral("createdAt"),
                       formatIsoDateTime(item.value(QStringLiteral("createdAt")).toString()));
            row.insert(QStringLiteral("total"),
                       item.value(QStringLiteral("total")).toString());

            rows.append(row);
        }

        m_transactionReceipts = rows;
        emit transactionReceiptsChanged();

        setStatus(QStringLiteral("Loaded %1 receipt(s).").arg(rows.size()));
    });
}

QVariantList StarlingClient::transactionAttachments() const
{
    return m_transactionAttachments;
}

void StarlingClient::refreshTransactionAttachments(const QString &feedItemUid)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    m_transactionAttachments.clear();
    emit transactionAttachmentsChanged();

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/attachments")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Loading transaction attachments..."));

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("attachments")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("feedItemAttachments")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("feedItemAttachmentUid"),
                       item.value(QStringLiteral("feedItemAttachmentUid")).toString(
                           item.value(QStringLiteral("uid")).toString()));
            row.insert(QStringLiteral("name"),
                       item.value(QStringLiteral("name")).toString(
                           item.value(QStringLiteral("filename")).toString()));
            row.insert(QStringLiteral("contentType"),
                       item.value(QStringLiteral("contentType")).toString(
                           item.value(QStringLiteral("mimeType")).toString()));
            row.insert(QStringLiteral("createdAt"),
                       formatIsoDateTime(item.value(QStringLiteral("createdAt")).toString()));

            rows.append(row);
        }

        m_transactionAttachments = rows;
        emit transactionAttachmentsChanged();

        setStatus(QStringLiteral("Loaded %1 attachment(s).").arg(rows.size()));
    });
}

QVariantMap StarlingClient::transactionDetail() const
{
    return m_transactionDetail;
}

void StarlingClient::refreshTransactionDetail(const QString &feedItemUid)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    m_transactionDetail.clear();
    emit transactionDetailChanged();

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Loading transaction details..."));

    getJson(path, [this, trimmedUid](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        QJsonObject item = doc.object();

        if (item.contains(QStringLiteral("feedItem")))
            item = item.value(QStringLiteral("feedItem")).toObject();

        QVariantMap detail;
        detail.insert(QStringLiteral("feedItemUid"), trimmedUid);
        detail.insert(QStringLiteral("counterPartyName"), item.value(QStringLiteral("counterPartyName")).toString());
        detail.insert(QStringLiteral("counterPartyType"), item.value(QStringLiteral("counterPartyType")).toString());
        detail.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());
        detail.insert(QStringLiteral("userNote"), item.value(QStringLiteral("userNote")).toString());
        detail.insert(QStringLiteral("spendingCategory"), item.value(QStringLiteral("spendingCategory")).toString());
        detail.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());
        detail.insert(QStringLiteral("source"), item.value(QStringLiteral("source")).toString());
        detail.insert(QStringLiteral("direction"), item.value(QStringLiteral("direction")).toString());
        detail.insert(QStringLiteral("transactionTime"), formatIsoDateTime(item.value(QStringLiteral("transactionTime")).toString()));
        detail.insert(QStringLiteral("settlementTime"), formatIsoDateTime(item.value(QStringLiteral("settlementTime")).toString()));
        detail.insert(QStringLiteral("updatedAt"), formatIsoDateTime(item.value(QStringLiteral("updatedAt")).toString()));

        const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
        const QString currency = amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
        const qint64 minor = amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

        detail.insert(QStringLiteral("amount"), signedAmountString(detail.value(QStringLiteral("direction")).toString(),
                                                                   minor,
                                                                   currency));
        detail.insert(QStringLiteral("currency"), currency);

        m_transactionDetail = detail;
        emit transactionDetailChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Transaction details loaded."));
    });
}

// Spaces
QVariantList StarlingClient::spaces() const
{
    return m_spaces;
}

qint64 StarlingClient::availableBalanceMinorUnits() const
{
    return m_availableBalanceMinorUnits;
}

void StarlingClient::refreshSpaces()
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    setStatus(QStringLiteral("Loading spaces..."));

    const QString path =
            QStringLiteral("/api/v2/account/%1/spaces")
            .arg(m_accountUid);

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("spaces")).toArray();

        if (items.isEmpty())
            items = root.value(QStringLiteral("savingsGoals")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            QVariantMap row;

            const QString spaceUid = item.value(QStringLiteral("spaceUid")).toString(
                        item.value(QStringLiteral("savingsGoalUid")).toString());

            const QString name = item.value(QStringLiteral("name")).toString(
                        item.value(QStringLiteral("savingsGoalName")).toString());

            const QString type = item.value(QStringLiteral("spaceType")).toString(
                        item.value(QStringLiteral("type")).toString());

            const QJsonObject balance =
                    item.value(QStringLiteral("balance")).toObject();

            const QJsonObject target =
                    item.value(QStringLiteral("target")).toObject();

            const QJsonObject savedAmount =
                    item.value(QStringLiteral("savedAmount")).toObject();

            const QJsonObject totalSaved =
                    item.value(QStringLiteral("totalSaved")).toObject();

            const QJsonObject balanceAmount =
                    !balance.isEmpty() ? balance
                                       : (!savedAmount.isEmpty() ? savedAmount : totalSaved);

            const QString currency =
                    balanceAmount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));

            const qint64 balanceMinor =
                    balanceAmount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            const QString targetCurrency =
                    target.value(QStringLiteral("currency")).toString(currency);

            const qint64 targetMinor =
                    target.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            row.insert(QStringLiteral("spaceUid"), spaceUid);
            row.insert(QStringLiteral("name"), name.isEmpty() ? QStringLiteral("Space") : name);
            row.insert(QStringLiteral("type"), type);
            row.insert(QStringLiteral("state"), item.value(QStringLiteral("state")).toString());
            row.insert(QStringLiteral("balance"), formatMinorUnits(balanceMinor, currency));
            row.insert(QStringLiteral("target"), targetMinor > 0 ? formatMinorUnits(targetMinor, targetCurrency) : QString());
            row.insert(QStringLiteral("currency"), currency);
            row.insert(QStringLiteral("createdAt"), formatIsoDateTime(item.value(QStringLiteral("createdAt")).toString()));
            row.insert(QStringLiteral("updatedAt"), formatIsoDateTime(item.value(QStringLiteral("updatedAt")).toString()));
            row.insert(QStringLiteral("balanceMinorUnits"), balanceMinor);

            rows.append(row);
        }

        m_spaces = rows;
        emit spacesChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Loaded %1 space(s).").arg(rows.size()));
    });
}

// Saving goals
void StarlingClient::createSavingsGoal(const QString &name, const QString &targetAmount)
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedName = name.trimmed();
    if (trimmedName.isEmpty()) {
        setStatus(QStringLiteral("Savings goal name is missing."));
        return;
    }

    QString amountText = targetAmount.trimmed();
    amountText.replace(QStringLiteral(","), QStringLiteral("."));

    bool ok = false;
    const double amountMajor = amountText.toDouble(&ok);

    if (!ok || amountMajor <= 0.0) {
        setStatus(QStringLiteral("Invalid target amount."));
        return;
    }

    const qint64 minorUnits = qRound64(amountMajor * 100.0);

    QJsonObject target;
    target.insert(QStringLiteral("currency"), QStringLiteral("GBP"));
    target.insert(QStringLiteral("minorUnits"), minorUnits);

    QJsonObject body;
    body.insert(QStringLiteral("name"), trimmedName);
    body.insert(QStringLiteral("currency"), QStringLiteral("GBP"));
    body.insert(QStringLiteral("target"), target);

    const QString path =
            QStringLiteral("/api/v2/account/%1/savings-goals")
            .arg(m_accountUid);

    setStatus(QStringLiteral("Creating savings goal..."));

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Savings goal created."));
        refreshSpaces();
        touchLastUpdated();
        emit savingsGoalCreated();
    }, false);
}

void StarlingClient::addMoneyToSavingsGoal(const QString &savingsGoalUid, const QString &amount)
{
    transferSavingsGoalMoney(savingsGoalUid, amount, true);
}

void StarlingClient::withdrawMoneyFromSavingsGoal(const QString &savingsGoalUid, const QString &amount)
{
    transferSavingsGoalMoney(savingsGoalUid, amount, false);
}

void StarlingClient::transferSavingsGoalMoney(const QString &savingsGoalUid,
                                              const QString &amount,
                                              bool addMoney)
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedGoalUid = savingsGoalUid.trimmed();
    if (trimmedGoalUid.isEmpty()) {
        setStatus(QStringLiteral("Savings goal UID is missing."));
        return;
    }

    QString amountText = amount.trimmed();
    amountText.replace(QStringLiteral(","), QStringLiteral("."));

    bool ok = false;
    const double amountMajor = amountText.toDouble(&ok);

    if (!ok || amountMajor <= 0.0) {
        setStatus(QStringLiteral("Invalid amount."));
        return;
    }

    const qint64 minorUnits = qRound64(amountMajor * 100.0);

    QJsonObject money;
    money.insert(QStringLiteral("currency"), QStringLiteral("GBP"));
    money.insert(QStringLiteral("minorUnits"), minorUnits);

    QJsonObject body;
    body.insert(QStringLiteral("amount"), money);

    QString transferUid = QUuid::createUuid().toString();
    transferUid.remove(QLatin1Char('{'));
    transferUid.remove(QLatin1Char('}'));

    const QString action = addMoney
            ? QStringLiteral("add-money")
            : QStringLiteral("withdraw-money");

    const QString path =
            QStringLiteral("/api/v2/account/%1/savings-goals/%2/%3/%4")
            .arg(m_accountUid)
            .arg(trimmedGoalUid)
            .arg(action)
            .arg(transferUid);

    setStatus(addMoney
              ? QStringLiteral("Adding money to savings goal...")
              : QStringLiteral("Withdrawing money from savings goal..."));

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this, addMoney](const QByteArray &) {
        setStatus(addMoney
                  ? QStringLiteral("Money added to savings goal.")
                  : QStringLiteral("Money withdrawn from savings goal."));

        refreshSpaces();
        refreshBalance();
        touchLastUpdated();
        emit savingsGoalTransferCompleted();
    }, false);
}

void StarlingClient::deleteSavingsGoal(const QString &savingsGoalUid)
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedGoalUid = savingsGoalUid.trimmed();
    if (trimmedGoalUid.isEmpty()) {
        setStatus(QStringLiteral("Savings goal UID is missing."));
        return;
    }

    setStatus(QStringLiteral("Deleting savings goal..."));

    const QString path =
            QStringLiteral("/api/v2/account/%1/savings-goals/%2")
            .arg(m_accountUid)
            .arg(trimmedGoalUid);

    sendDeleteWithToken(path, m_token, [this](const QByteArray &) {
        setStatus(QStringLiteral("Savings goal deleted."));
        refreshSpaces();
        refreshBalance();
        touchLastUpdated();
        emit savingsGoalDeleted();
    });
}

// RoundUp
QVariantMap StarlingClient::roundUp() const
{
    return m_roundUp;
}

bool StarlingClient::roundUpLoaded() const
{
    return m_roundUpLoaded;
}

void StarlingClient::refreshRoundUp()
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/round-up")
            .arg(m_accountUid);

    setStatus(QStringLiteral("Loading round-up status..."));

    getJson(path, [this](const QByteArray &body) {

        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QVariantMap data;

        const bool active = root.value(QStringLiteral("active")).toBool(false);
        const QJsonObject details = root.value(QStringLiteral("roundUpGoalDetails")).toObject();

        const QString goalUid = details.value(QStringLiteral("roundUpGoalUid")).toString();
        const int multiplier = qRound(details.value(QStringLiteral("roundUpMultiplier")).toDouble(1.0));

        data.insert(QStringLiteral("active"), active);
        data.insert(QStringLiteral("roundUpGoalUid"), goalUid);
        data.insert(QStringLiteral("roundUpMultiplier"), multiplier > 0 ? multiplier : 1);
        data.insert(QStringLiteral("activatedAt"),
                    formatIsoDateTime(details.value(QStringLiteral("activatedAt")).toString()));
        data.insert(QStringLiteral("activatedBy"), details.value(QStringLiteral("activatedBy")).toString());
        data.insert(QStringLiteral("primaryCategoryUid"), details.value(QStringLiteral("primaryCategoryUid")).toString());

        QString goalName;
        for (int i = 0; i < m_spaces.size(); ++i) {
            const QVariantMap space = m_spaces.at(i).toMap();

            if (space.value(QStringLiteral("spaceUid")).toString() == goalUid) {
                goalName = space.value(QStringLiteral("name")).toString();
                break;
            }
        }

        data.insert(QStringLiteral("goalName"), goalName);

        m_roundUp = data;
        m_roundUpLoaded = true;
        emit roundUpChanged();

        setStatus(QStringLiteral("Round-up status loaded."));
        touchLastUpdated();
    });
}

void StarlingClient::disableRoundUp()
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/round-up")
            .arg(m_accountUid);

    setStatus(QStringLiteral("Disabling round-up..."));

    sendDeleteWithToken(path, m_token, [this](const QByteArray &) {
        setStatus(QStringLiteral("Round-up disabled."));
        refreshRoundUp();
        touchLastUpdated();
        emit roundUpUpdated();
    });
}

void StarlingClient::enableRoundUp(const QString &roundUpGoalUid, int multiplier)
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedGoalUid = roundUpGoalUid.trimmed();

    if (trimmedGoalUid.isEmpty()) {
        setStatus(QStringLiteral("Savings goal is missing."));
        return;
    }

    if (multiplier < 1 || multiplier > 10) {
        setStatus(QStringLiteral("Round-up multiplier must be between 1 and 10."));
        return;
    }

    QJsonObject body;
    body.insert(QStringLiteral("roundUpGoalUid"), trimmedGoalUid);
    body.insert(QStringLiteral("roundUpMultiplier"), multiplier);

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/round-up")
            .arg(m_accountUid);

    setStatus(QStringLiteral("Enabling round-up..."));

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Round-up enabled."));
        refreshRoundUp();
        touchLastUpdated();
        emit roundUpUpdated();
    }, false);
}

// Feed Extract Csv - Statements/transactions
QString StarlingClient::lastFeedExportCsvPath() const
{
    return m_lastFeedExportCsvPath;
}

void StarlingClient::downloadFeedExportCsvRange(const QString &startDate, const QString &endDate)
{
    if (m_accountUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedStartDate = startDate.trimmed();
    const QString trimmedEndDate = endDate.trimmed();

    const QDate start = QDate::fromString(trimmedStartDate, Qt::ISODate);
    const QDate end = QDate::fromString(trimmedEndDate, Qt::ISODate);

    if (!start.isValid() || !end.isValid()) {
        setStatus(QStringLiteral("Invalid transaction export date range."));
        return;
    }

    if (start > end) {
        setStatus(QStringLiteral("Start date must be before end date."));
        return;
    }

    QUrl url(QStringLiteral("%1/api/v2/accounts/%2/feed-export")
             .arg(QString::fromLatin1(BASE_URL))
             .arg(m_accountUid));

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("start"), trimmedStartDate);
    query.addQueryItem(QStringLiteral("end"), trimmedEndDate);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    req.setRawHeader("Accept", "text/csv");

    setStatus(QStringLiteral("Downloading feed export CSV..."));
    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep, trimmedStartDate, trimmedEndDate]() {
        const QByteArray body = rep->readAll();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "downloadFeedExportCsvRange failed url=" << rep->url()
                       << "status=" << rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(body);

            setStatus(QStringLiteral("Transaction export CSV download failed: %1").arg(rep->errorString()));
            rep->deleteLater();
            endRequest();
            return;
        }

        const QString docsRoot = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        QDir dir(docsRoot + QStringLiteral("/Starling Transaction Exports"));

        if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
            setStatus(QStringLiteral("Could not create trasnaction export folder."));
            rep->deleteLater();
            endRequest();
            return;
        }

        const QString fileName =
                QStringLiteral("starling-transaction-export-%1-to-%2.csv")
                .arg(trimmedStartDate)
                .arg(trimmedEndDate);

        const QString filePath = dir.filePath(fileName);

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            setStatus(QStringLiteral("Could not save transaction export CSV."));
            rep->deleteLater();
            endRequest();
            return;
        }

        file.write(body);
        file.close();

        m_lastFeedExportCsvPath = filePath;
        emit lastFeedExportCsvPathChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Transaction export CSV saved: %1").arg(filePath));

        rep->deleteLater();
        endRequest();
    });
}

// Direct Debits/Mandates & Standing Orders
QVariantList StarlingClient::directDebitPayments() const
{
    return m_directDebitPayments;
}

void StarlingClient::refreshDirectDebitPayments(const QString &mandateUid)
{
    const QString trimmedUid = mandateUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Direct Debit mandate UID is missing."));
        return;
    }

    m_directDebitPayments.clear();
    emit directDebitPaymentsChanged();

    setStatus(QStringLiteral("Loading Direct Debit payments..."));

    const QString path =
            QStringLiteral("/api/v2/direct-debit/mandates/%1/payments")
            .arg(trimmedUid);

    QUrl url(QString::fromLatin1(BASE_URL) + path);

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("since"),
                       QDate::currentDate().addYears(-1).toString(Qt::ISODate));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());

    beginRequest();

    QNetworkReply *rep = m_nam.get(req);

    connect(rep, &QNetworkReply::finished, this, [this, rep]() {
        const QByteArray body = rep->readAll();
        const int httpStatus =
                rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (rep->error() != QNetworkReply::NoError) {
            qWarning() << "refreshDirectDebitPayments failed url=" << rep->url()
                       << "status=" << httpStatus
                       << "qtError=" << rep->errorString()
                       << "body=" << QString::fromUtf8(body);

            m_directDebitPayments.clear();
            emit directDebitPaymentsChanged();

            if (httpStatus == 400) {
                setStatus(QStringLiteral("No Direct Debit payments found."));
            } else {
                setStatus(QStringLiteral("Direct Debit payment history unavailable."));
            }

            rep->deleteLater();
            endRequest();
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("payments")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("directDebitPayments")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QString currency =
                    amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor =
                    amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            QVariantMap row;
            row.insert(QStringLiteral("date"),
                       item.value(QStringLiteral("date")).toString(
                           item.value(QStringLiteral("paymentDate")).toString(
                               item.value(QStringLiteral("created")).toString())));
            row.insert(QStringLiteral("amount"),
                       minor > 0 ? formatMinorUnits(minor, currency) : QString());
            row.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());
            row.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());

            rows.append(row);
        }

        m_directDebitPayments = rows;
        emit directDebitPaymentsChanged();

        setStatus(rows.isEmpty()
                  ? QStringLiteral("No Direct Debit payments found.")
                  : QStringLiteral("Loaded %1 Direct Debit payment(s).").arg(rows.size()));

        rep->deleteLater();
        endRequest();
    });
}

QVariantList StarlingClient::standingOrderPaymentHistory() const
{
    return m_standingOrderPaymentHistory;
}

QVariantList StarlingClient::standingOrderUpcomingPayments() const
{
    return m_standingOrderUpcomingPayments;
}

bool StarlingClient::regularPaymentsLoaded() const
{
    return m_directDebitMandatesLoaded && m_standingOrdersLoaded;
}

QVariantList StarlingClient::directDebitMandates() const
{
    return m_directDebitMandates;
}

QVariantList StarlingClient::standingOrders() const
{
    return m_standingOrders;
}

void StarlingClient::refreshStandingOrderPaymentHistory(const QString &paymentOrderUid)
{
    const QString trimmedUid = paymentOrderUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Standing Order UID is missing."));
        return;
    }

    m_standingOrderPaymentHistory.clear();
    emit standingOrderPaymentHistoryChanged();

    setStatus(QStringLiteral("Loading Standing Order payment history..."));

    const QString path =
            QStringLiteral("/api/v2/payments/local/payment-order/%1/payments")
            .arg(trimmedUid);

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("payments")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("paymentOrders")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QString currency = amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor = amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            QVariantMap row;
            row.insert(QStringLiteral("paymentUid"), item.value(QStringLiteral("paymentUid")).toString());
            row.insert(QStringLiteral("date"),
                       item.value(QStringLiteral("createdAt")).toString(
                           item.value(QStringLiteral("paymentDate")).toString(
                               item.value(QStringLiteral("date")).toString())));
            row.insert(QStringLiteral("amount"), minor > 0 ? formatMinorUnits(minor, currency) : QString());
            row.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());
            row.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());

            rows.append(row);
        }

        m_standingOrderPaymentHistory = rows;
        emit standingOrderPaymentHistoryChanged();

        setStatus(QStringLiteral("Loaded %1 payment history item(s).").arg(rows.size()));
    });
}

void StarlingClient::refreshRegularPayments()
{
    setStatus(QStringLiteral("Loading regular payments..."));

    m_directDebitMandatesLoaded = false;
    m_standingOrdersLoaded = false;
    emit regularPaymentsLoadedChanged();

    refreshDirectDebitMandates();
    refreshStandingOrders();
}

void StarlingClient::refreshStandingOrderUpcomingPayments(const QString &paymentOrderUid)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = paymentOrderUid.trimmed();
    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Standing Order UID is missing."));
        return;
    }

    m_standingOrderUpcomingPayments.clear();
    emit standingOrderUpcomingPaymentsChanged();

    setStatus(QStringLiteral("Loading upcoming payments..."));

    const QString path =
            QStringLiteral("/api/v2/payments/local/account/%1/category/%2/standing-orders/%3/upcoming-payments")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("upcomingPayments")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("payments")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("date"),
                       item.value(QStringLiteral("date")).toString(
                           item.value(QStringLiteral("paymentDate")).toString(
                               item.value(QStringLiteral("scheduledDate")).toString())));

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QString currency = amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor = amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            row.insert(QStringLiteral("amount"), minor > 0 ? formatMinorUnits(minor, currency) : QString());
            row.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());

            rows.append(row);
        }

        m_standingOrderUpcomingPayments = rows;
        emit standingOrderUpcomingPaymentsChanged();

        setStatus(QStringLiteral("Loaded %1 upcoming payment(s).").arg(rows.size()));
    });
}

void StarlingClient::refreshDirectDebitMandates()
{
    setStatus(QStringLiteral("Loading Direct Debits..."));

    getJson(QStringLiteral("/api/v2/direct-debit/mandates"),
            [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("mandates")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("directDebitMandates")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            QVariantMap row;

            const QString uid = item.value(QStringLiteral("uid")).toString(
                        item.value(QStringLiteral("mandateUid")).toString());

            row.insert(QStringLiteral("mandateUid"), uid);
            row.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());
            row.insert(QStringLiteral("status"), item.value(QStringLiteral("status")).toString());
            const QString ddStatus = row.value(QStringLiteral("status")).toString();
            const bool ddActive = ddStatus == QStringLiteral("LIVE")
                    || ddStatus == QStringLiteral("PENDING_CAS");

            row.insert(QStringLiteral("displayStatus"),
                       ddActive ? QStringLiteral("Active") : QStringLiteral("Cancelled"));
            row.insert(QStringLiteral("isActive"), ddActive);
            row.insert(QStringLiteral("source"), item.value(QStringLiteral("source")).toString());
            row.insert(QStringLiteral("created"), formatIsoDateTime(item.value(QStringLiteral("created")).toString()));
            row.insert(QStringLiteral("cancelled"), formatIsoDateTime(item.value(QStringLiteral("cancelled")).toString()));
            row.insert(QStringLiteral("nextDate"), item.value(QStringLiteral("nextDate")).toString());
            row.insert(QStringLiteral("lastDate"), item.value(QStringLiteral("lastDate")).toString());
            row.insert(QStringLiteral("originatorName"), item.value(QStringLiteral("originatorName")).toString());
            row.insert(QStringLiteral("originatorUid"), item.value(QStringLiteral("originatorUid")).toString());
            row.insert(QStringLiteral("merchantUid"), item.value(QStringLiteral("merchantUid")).toString());
            row.insert(QStringLiteral("accountUid"), item.value(QStringLiteral("accountUid")).toString());
            row.insert(QStringLiteral("categoryUid"), item.value(QStringLiteral("categoryUid")).toString());

            const QJsonObject lastPayment = item.value(QStringLiteral("lastPayment")).toObject();
            row.insert(QStringLiteral("lastPaymentDate"), lastPayment.value(QStringLiteral("lastDate")).toString());

            const QJsonObject lastAmount = lastPayment.value(QStringLiteral("lastAmount")).toObject();
            const QString lastCurrency = lastAmount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 lastMinor = lastAmount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            row.insert(QStringLiteral("lastPaymentAmount"),
                       lastPayment.isEmpty() ? QString() : formatMinorUnits(lastMinor, lastCurrency));

            QString title = row.value(QStringLiteral("originatorName")).toString();
            if (title.isEmpty())
                title = row.value(QStringLiteral("reference")).toString();
            if (title.isEmpty())
                title = QStringLiteral("Direct Debit");

            row.insert(QStringLiteral("title"), title);
            rows.append(row);
        }

        m_directDebitMandates = rows;
        emit directDebitMandatesChanged();
        m_directDebitMandatesLoaded = true;
        emit regularPaymentsLoadedChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Loaded %1 Direct Debit mandate(s).").arg(rows.size()));
    });
}

void StarlingClient::refreshStandingOrders()
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        if (!m_initializing)
            initialize(m_startupDaysBack > 0 ? m_startupDaysBack : 14);
        return;
    }

    setStatus(QStringLiteral("Loading Standing Orders..."));

    const QString path =
            QStringLiteral("/api/v2/payments/local/account/%1/category/%2/standing-orders")
            .arg(m_accountUid)
            .arg(m_categoryUid);

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        QJsonArray items = root.value(QStringLiteral("standingOrders")).toArray();
        if (items.isEmpty())
            items = root.value(QStringLiteral("paymentOrders")).toArray();

        QVariantList rows;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QString currency = amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor = amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            const QJsonObject recurrence = item.value(QStringLiteral("standingOrderRecurrence")).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("paymentOrderUid"), item.value(QStringLiteral("paymentOrderUid")).toString());
            row.insert(QStringLiteral("reference"), item.value(QStringLiteral("reference")).toString());
            row.insert(QStringLiteral("payeeUid"), item.value(QStringLiteral("payeeUid")).toString());
            row.insert(QStringLiteral("payeeAccountUid"), item.value(QStringLiteral("payeeAccountUid")).toString());
            row.insert(QStringLiteral("nextDate"), item.value(QStringLiteral("nextDate")).toString());
            row.insert(QStringLiteral("cancelledAt"), formatIsoDateTime(item.value(QStringLiteral("cancelledAt")).toString()));
            row.insert(QStringLiteral("updatedAt"), formatIsoDateTime(item.value(QStringLiteral("updatedAt")).toString()));
            row.insert(QStringLiteral("spendingCategory"), item.value(QStringLiteral("spendingCategory")).toString());
            row.insert(QStringLiteral("categoryUid"), item.value(QStringLiteral("categoryUid")).toString());
            row.insert(QStringLiteral("amount"), formatMinorUnits(minor, currency));

            row.insert(QStringLiteral("startDate"), recurrence.value(QStringLiteral("startDate")).toString());
            row.insert(QStringLiteral("frequency"), recurrence.value(QStringLiteral("frequency")).toString());
            row.insert(QStringLiteral("interval"), recurrence.value(QStringLiteral("interval")).toVariant().toString());
            row.insert(QStringLiteral("count"), recurrence.value(QStringLiteral("count")).toVariant().toString());
            row.insert(QStringLiteral("untilDate"), recurrence.value(QStringLiteral("untilDate")).toString());

            const QString cancelledAt = row.value(QStringLiteral("cancelledAt")).toString();
            const QString nextDate = row.value(QStringLiteral("nextDate")).toString();
            const QString count = row.value(QStringLiteral("count")).toString();

            const bool cancelled = !cancelledAt.isEmpty();
            const bool completed = !cancelled && !count.isEmpty() && nextDate.isEmpty();

            QString displayStatus;
            if (cancelled)
                displayStatus = QStringLiteral("Cancelled");
            else if (completed)
                displayStatus = QStringLiteral("Completed");
            else
                displayStatus = QStringLiteral("Active");

            row.insert(QStringLiteral("status"), displayStatus.toUpper());
            row.insert(QStringLiteral("displayStatus"), displayStatus);
            row.insert(QStringLiteral("isActive"), displayStatus == QStringLiteral("Active"));
            row.insert(QStringLiteral("isCompleted"), completed);

            QString title = row.value(QStringLiteral("reference")).toString();
            if (title.isEmpty())
                title = QStringLiteral("Standing Order");

            row.insert(QStringLiteral("title"), title);
            rows.append(row);
        }

        m_standingOrders = rows;
        emit standingOrdersChanged();
        m_standingOrdersLoaded = true;
        emit regularPaymentsLoadedChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Loaded %1 Standing Order(s).").arg(rows.size()));
    });
}

void StarlingClient::cancelDirectDebitMandate(const QString &mandateUid)
{
    const QString trimmedUid = mandateUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Direct Debit mandate UID is missing."));
        return;
    }

    setStatus(QStringLiteral("Cancelling Direct Debit..."));

    const QString path =
            QStringLiteral("/api/v2/direct-debit/mandates/%1")
            .arg(trimmedUid);

    sendDeleteWithToken(path, m_token, [this](const QByteArray &) {
        setStatus(QStringLiteral("Direct Debit cancelled."));
        refreshDirectDebitMandates();
        touchLastUpdated();
    });
}

void StarlingClient::cancelStandingOrder(const QString &paymentOrderUid)
{
    const QString trimmedUid = paymentOrderUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Standing Order UID is missing."));
        return;
    }

    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    setStatus(QStringLiteral("Cancelling Standing Order..."));

    const QString path =
            QStringLiteral("/api/v2/payments/local/account/%1/category/%2/standing-orders/%3")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    sendJsonWithToken(path,
                      QStringLiteral("DELETE"),
                      QJsonObject(),
                      m_token,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Standing Order cancelled."));
        refreshStandingOrders();
        touchLastUpdated();
    }, true);
}

// Payments
QVariantList StarlingClient::sourceAccounts() const
{
    return m_sourceAccounts;
}

QVariantMap StarlingClient::paymentDraft() const
{
    return m_paymentDraft;
}

QString StarlingClient::paymentPreviewJson() const
{
    return m_paymentPreviewJson;
}

bool StarlingClient::paymentPreviewReady() const
{
    return m_paymentPreviewReady;
}

void StarlingClient::clearPaymentDraft()
{
    m_paymentDraft.clear();
    m_paymentPreviewJson.clear();
    m_paymentPreviewReady = false;

    emit paymentDraftChanged();
    emit paymentPreviewJsonChanged();
    emit paymentPreviewReadyChanged();
}

void StarlingClient::preparePaymentDraft(const QString &sourceAccountUid,
                                         const QString &categoryUid,
                                         const QString &sourceAccountName,
                                         const QString &sourceAccountNumber,
                                         const QString &sourceSortCode,
                                         const QString &payeeUid,
                                         const QString &payeeName,
                                         const QString &destinationPayeeAccountUid,
                                         const QString &accountDescription,
                                         const QString &accountIdentifier,
                                         const QString &bankIdentifier,
                                         const QString &amountText,
                                         const QString &reference)
{
    m_paymentDraft.clear();
    m_paymentPreviewJson.clear();
    m_paymentPreviewReady = false;

    m_paymentDraft.insert(QStringLiteral("sourceAccountUid"), sourceAccountUid.trimmed());
    m_paymentDraft.insert(QStringLiteral("categoryUid"), categoryUid.trimmed());
    m_paymentDraft.insert(QStringLiteral("sourceAccountName"), sourceAccountName.trimmed());
    m_paymentDraft.insert(QStringLiteral("sourceAccountNumber"), sourceAccountNumber.trimmed());
    m_paymentDraft.insert(QStringLiteral("sourceSortCode"), sourceSortCode.trimmed());

    m_paymentDraft.insert(QStringLiteral("payeeUid"), payeeUid.trimmed());
    m_paymentDraft.insert(QStringLiteral("payeeName"), payeeName.trimmed());
    m_paymentDraft.insert(QStringLiteral("destinationPayeeAccountUid"), destinationPayeeAccountUid.trimmed());
    m_paymentDraft.insert(QStringLiteral("accountDescription"), accountDescription.trimmed());
    m_paymentDraft.insert(QStringLiteral("accountIdentifier"), accountIdentifier.trimmed());
    m_paymentDraft.insert(QStringLiteral("bankIdentifier"), bankIdentifier.trimmed());
    m_paymentDraft.insert(QStringLiteral("amountText"), amountText.trimmed());
    m_paymentDraft.insert(QStringLiteral("reference"), reference.trimmed());
    m_paymentDraft.insert(QStringLiteral("currency"), QStringLiteral("GBP"));

    emit paymentDraftChanged();
    emit paymentPreviewJsonChanged();
    emit paymentPreviewReadyChanged();
}

bool StarlingClient::buildPaymentPreview()
{
    const QString sourceAccountUid =
            m_paymentDraft.value(QStringLiteral("sourceAccountUid")).toString().trimmed();
    const QString categoryUid =
            m_paymentDraft.value(QStringLiteral("categoryUid")).toString().trimmed();
    const QString payeeName =
            m_paymentDraft.value(QStringLiteral("payeeName")).toString().trimmed();
    const QString destinationPayeeAccountUid =
            m_paymentDraft.value(QStringLiteral("destinationPayeeAccountUid")).toString().trimmed();
    const QString amountText =
            m_paymentDraft.value(QStringLiteral("amountText")).toString().trimmed();
    const QString reference =
            m_paymentDraft.value(QStringLiteral("reference")).toString().trimmed();

    if (sourceAccountUid.isEmpty()) {
        setStatus(QStringLiteral("Missing source account UID."));
        return false;
    }

    if (categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Missing category UID."));
        return false;
    }

    if (payeeName.isEmpty()) {
        setStatus(QStringLiteral("Missing payee name."));
        return false;
    }

    if (destinationPayeeAccountUid.isEmpty()) {
        setStatus(QStringLiteral("Missing destination payee account UID."));
        return false;
    }

    if (amountText.isEmpty()) {
        setStatus(QStringLiteral("Enter an amount."));
        return false;
    }

    if (reference.isEmpty()) {
        setStatus(QStringLiteral("Enter a payment reference."));
        return false;
    }

    bool ok = false;
    const double amount = amountText.toDouble(&ok);
    if (!ok || amount <= 0.0) {
        setStatus(QStringLiteral("Enter a valid amount."));
        return false;
    }

    if (reference.length() > 18) {
        setStatus(QStringLiteral("Reference must be 18 characters or fewer."));
        return false;
    }

    const qint64 minorUnits = qRound64(amount * 100.0);
    if (minorUnits <= 0) {
        setStatus(QStringLiteral("Enter a valid amount."));
        return false;
    }

    const QString externalIdentifier =
            QUuid::createUuid().toString().remove('{').remove('}');

    m_paymentDraft.insert(QStringLiteral("amountMinorUnits"), minorUnits);
    m_paymentDraft.insert(QStringLiteral("amountDisplay"),
                          QStringLiteral("£%1").arg(QString::number(amount, 'f', 2)));
    m_paymentDraft.insert(QStringLiteral("externalIdentifier"), externalIdentifier);
    m_paymentDraft.insert(QStringLiteral("requestMethod"), QStringLiteral("PUT"));

    const QString requestPath =
            QStringLiteral("/api/v2/payments/local/account/%1/category/%2")
            .arg(sourceAccountUid, categoryUid);

    m_paymentDraft.insert(QStringLiteral("requestPath"), requestPath);

    QJsonObject root;
    root.insert(QStringLiteral("externalIdentifier"), externalIdentifier);
    root.insert(QStringLiteral("destinationPayeeAccountUid"), destinationPayeeAccountUid);
    root.insert(QStringLiteral("reference"), reference);

    QJsonObject amountObj;
    amountObj.insert(QStringLiteral("currency"), QStringLiteral("GBP"));
    amountObj.insert(QStringLiteral("minorUnits"), static_cast<qint64>(minorUnits));
    root.insert(QStringLiteral("amount"), amountObj);

    QJsonDocument doc(root);
    m_paymentPreviewJson = QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
    m_paymentPreviewReady = true;

    emit paymentDraftChanged();
    emit paymentPreviewJsonChanged();
    emit paymentPreviewReadyChanged();

    setStatus(QStringLiteral("Payment preview ready."));
    return true;
}

bool StarlingClient::paymentSubmitting() const
{
    return m_paymentSubmitting;
}

bool StarlingClient::paymentSubmitted() const
{
    return m_paymentSubmitted;
}

QString StarlingClient::paymentResultMessage() const
{
    return m_paymentResultMessage;
}

void StarlingClient::setPaymentSubmitting(bool value)
{
    if (m_paymentSubmitting == value)
        return;

    m_paymentSubmitting = value;
    emit paymentSubmittingChanged();
}

void StarlingClient::setPaymentSubmitted(bool value)
{
    if (m_paymentSubmitted == value)
        return;

    m_paymentSubmitted = value;
    emit paymentSubmittedChanged();
}

void StarlingClient::setPaymentResultMessage(const QString &value)
{
    if (m_paymentResultMessage == value)
        return;

    m_paymentResultMessage = value;
    emit paymentResultMessageChanged();
}

void StarlingClient::clearPaymentResult()
{
    setPaymentSubmitting(false);
    setPaymentSubmitted(false);
    setPaymentResultMessage(QString());
}

bool StarlingClient::submitPreparedPayment()
{
    if (m_apiKeyId.trimmed().isEmpty()) {
        setApiKeyId(m_tokenStore.loadApiKeyId());
    }

    if (m_privateApiKeyPem.trimmed().isEmpty()) {
        setPrivateApiKeyPem(m_tokenStore.loadPrivateApiKeyPem());
    }

    if (m_token.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Main token not loaded."));
        setStatus(QStringLiteral("Main token not loaded."));
        return false;
    }

    const QString sourceAccountUid =
            m_paymentDraft.value(QStringLiteral("sourceAccountUid")).toString().trimmed();
    const QString categoryUid =
            m_paymentDraft.value(QStringLiteral("categoryUid")).toString().trimmed();
    const QString destinationPayeeAccountUid =
            m_paymentDraft.value(QStringLiteral("destinationPayeeAccountUid")).toString().trimmed();
    const QString externalIdentifier =
            m_paymentDraft.value(QStringLiteral("externalIdentifier")).toString().trimmed();
    const QString reference =
            m_paymentDraft.value(QStringLiteral("reference")).toString().trimmed();
    const qint64 minorUnits =
            m_paymentDraft.value(QStringLiteral("amountMinorUnits")).toLongLong();
    const QString currency =
            m_paymentDraft.value(QStringLiteral("currency")).toString().trimmed();

    if (sourceAccountUid.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing source account UID."));
        return false;
    }

    if (categoryUid.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing category UID."));
        return false;
    }

    if (destinationPayeeAccountUid.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing destination payee account UID."));
        return false;
    }

    if (externalIdentifier.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing external identifier."));
        return false;
    }

    if (reference.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing payment reference."));
        return false;
    }

    if (currency.isEmpty()) {
        setPaymentResultMessage(QStringLiteral("Missing currency."));
        return false;
    }

    if (minorUnits <= 0) {
        setPaymentResultMessage(QStringLiteral("Invalid payment amount."));
        return false;
    }

    clearPaymentResult();
    setPaymentSubmitting(true);
    setStatus(QStringLiteral("Submitting payment..."));

    const QString path =
            QStringLiteral("/api/v2/payments/local/account/%1/category/%2")
            .arg(sourceAccountUid, categoryUid);

    QJsonObject payload;
    payload.insert(QStringLiteral("externalIdentifier"), externalIdentifier);
    payload.insert(QStringLiteral("destinationPayeeAccountUid"), destinationPayeeAccountUid);
    payload.insert(QStringLiteral("reference"), reference);

    QJsonObject amountObj;
    amountObj.insert(QStringLiteral("currency"), currency);
    amountObj.insert(QStringLiteral("minorUnits"), static_cast<qint64>(minorUnits));
    payload.insert(QStringLiteral("amount"), amountObj);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this](const QByteArray &body) {
        setPaymentSubmitting(false);
        setPaymentSubmitted(true);

        QString message = m_consentPending
                ? QStringLiteral("Payment pending approval in the Starling app.")
                : QStringLiteral("Payment submitted.");
        if (!body.isEmpty()) {
            const QJsonDocument doc = QJsonDocument::fromJson(body);
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();

                const QString paymentUid = obj.value(QStringLiteral("paymentUid")).toString();
                const QString status = obj.value(QStringLiteral("status")).toString();

                if (!paymentUid.isEmpty() && !status.isEmpty()) {
                    message = QStringLiteral("Payment submitted. UID: %1, status: %2")
                            .arg(paymentUid, status);
                } else if (!paymentUid.isEmpty()) {
                    message = QStringLiteral("Payment submitted. UID: %1").arg(paymentUid);
                } else if (!status.isEmpty()) {
                    message = QStringLiteral("Payment submitted. Status: %1").arg(status);
                }
            }
        }

        setPaymentResultMessage(message);
        setStatus(message);
    },
    true);

    return true;
}

// PIN management
bool StarlingClient::pinConfirmationPending() const
{
    return m_pinConfirmationPending;
}

void StarlingClient::requestPinConfirmation()
{
    if (!pinEnabled()) {
        setPinError(QString());
        setPinPromptVisible(false);
        return;
    }

//    if (!m_pinConfirmationPending) {
        m_pinConfirmationPending = true;
        emit pinConfirmationPendingChanged();
//    }

    setPinError(QString());
    setPinPromptVisible(true);
}

void StarlingClient::clearPinConfirmation()
{
    if (m_pinConfirmationPending) {
        m_pinConfirmationPending = false;
        emit pinConfirmationPendingChanged();
    }
}

bool StarlingClient::pinEnabled() const
{
    return !m_pinHash.isEmpty() && !m_pinSalt.isEmpty();
}

bool StarlingClient::pinPromptVisible() const
{
    return m_pinPromptVisible;
}

QString StarlingClient::pinError() const
{
    return m_pinError;
}

void StarlingClient::setPinPromptVisible(bool visible)
{
    if (m_pinPromptVisible == visible)
        return;

    m_pinPromptVisible = visible;
    emit pinPromptVisibleChanged();
}

void StarlingClient::setPinError(const QString &value)
{
    if (m_pinError == value)
        return;

    m_pinError = value;
    emit pinErrorChanged();
}

QString StarlingClient::hashPin(const QString &pin, const QString &salt) const
{
    const QByteArray data = (salt + QStringLiteral(":") + pin).toUtf8();
    return QString::fromLatin1(
        QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
}

bool StarlingClient::verifyPinValue(const QString &pin) const
{
    if (!pinEnabled())
        return false;

    return hashPin(pin, m_pinSalt) == m_pinHash;
}

bool StarlingClient::validateNewPin(const QString &pin,
                                    const QString &confirmPin,
                                    QString *error) const
{
    const QString p = pin.trimmed();
    const QString c = confirmPin.trimmed();

    if (p.isEmpty() || c.isEmpty()) {
        if (error)
            *error = QStringLiteral("PIN fields must not be empty.");
        return false;
    }

    if (p != c) {
        if (error)
            *error = QStringLiteral("PIN entries do not match.");
        return false;
    }

    if (p.length() < 4 || p.length() > 8) {
        if (error)
            *error = QStringLiteral("PIN must be 4 to 8 digits.");
        return false;
    }

    for (int i = 0; i < p.length(); ++i) {
        if (!p.at(i).isDigit()) {
            if (error)
                *error = QStringLiteral("PIN must contain digits only.");
            return false;
        }
    }

    return true;
}

// Local Card management
static QString maskCardholderName(const QString &input)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty())
        return QString();

    if (trimmed.length() == 1)
        return QStringLiteral("*");

    if (trimmed.length() == 2)
        return trimmed.left(1) + QStringLiteral("*");

    return trimmed.left(1)
            + QString(trimmed.length() - 2, QChar('*'))
            + trimmed.right(1);
}

static QString maskExpiry(const QString &month, const QString &year)
{
    Q_UNUSED(month)
    Q_UNUSED(year)
    return QStringLiteral("**/**");
}

static QString maskCardNumber(const QString &input)
{
    QString digits;
    for (const QChar &c : input) {
        if (c.isDigit()) {
            digits.append(c);
        }
    }

    if (digits.length() <= 4) {
        return digits;
    }

    const QString last4 = digits.right(4);
    return QStringLiteral("**** **** **** %1").arg(last4);
}

static QString normalizedCardNumber(const QString &input)
{
    QString digits;
    for (const QChar &c : input) {
        if (c.isDigit()) {
            digits.append(c);
        }
    }
    return digits;
}

bool StarlingClient::hasStoredPhysicalCard() const
{
    return !m_tokenStore.loadPhysicalCard().trimmed().isEmpty();
}

bool StarlingClient::savePhysicalCardAfterConfirmation(const QString &cardholderName,
                                                       const QString &cardNumber,
                                                       const QString &expiryMonth,
                                                       const QString &expiryYear)
{
    const QString cleanName = cardholderName.trimmed();
    const QString cleanNumber = normalizedCardNumber(cardNumber);
    const QString cleanMonth = expiryMonth.trimmed();
    const QString cleanYear = expiryYear.trimmed();

    if (cleanName.isEmpty() || cleanNumber.isEmpty()
            || cleanMonth.isEmpty() || cleanYear.isEmpty()) {
        setPinSettingsError(QStringLiteral("Please fill in all card fields."));
        return false;
    }

    if (cleanNumber.length() < 12 || cleanNumber.length() > 19) {
        setPinSettingsError(QStringLiteral("Card number looks invalid."));
        return false;
    }

    bool okMonth = false;
    const int month = cleanMonth.toInt(&okMonth);
    if (!okMonth || month < 1 || month > 12) {
        setPinSettingsError(QStringLiteral("Expiry month must be between 1 and 12."));
        return false;
    }

    if (cleanYear.length() < 2 || cleanYear.length() > 4) {
        setPinSettingsError(QStringLiteral("Expiry year looks invalid."));
        return false;
    }

    QJsonObject obj;
    obj.insert(QStringLiteral("cardholderName"), cleanName);
    obj.insert(QStringLiteral("cardNumber"), cleanNumber);
    obj.insert(QStringLiteral("expiryMonth"), cleanMonth);
    obj.insert(QStringLiteral("expiryYear"), cleanYear);

    const QString json = QString::fromUtf8(
                QJsonDocument(obj).toJson(QJsonDocument::Compact));

    if (!m_tokenStore.savePhysicalCard(json)) {
        setPinSettingsError(QStringLiteral("Failed to save physical card."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

QVariantMap StarlingClient::loadStoredPhysicalCardMasked() const
{
    QVariantMap result;

    const QString json = m_tokenStore.loadPhysicalCard().trimmed();
    if (json.isEmpty()) {
        return result;
    }

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        return QVariantMap{};
    }

    const QJsonObject obj = doc.object();
    const QString name = obj.value(QStringLiteral("cardholderName")).toString();
    const QString number = obj.value(QStringLiteral("cardNumber")).toString();
    const QString month = obj.value(QStringLiteral("expiryMonth")).toString();
    const QString year = obj.value(QStringLiteral("expiryYear")).toString();

    result.insert(QStringLiteral("cardholderName"), maskCardholderName(name));
    result.insert(QStringLiteral("cardNumber"), maskCardNumber(number));
    result.insert(QStringLiteral("expiryMonth"), QStringLiteral("**"));
    result.insert(QStringLiteral("expiryYear"), QStringLiteral("**"));
    result.insert(QStringLiteral("expiry"), maskExpiry(month, year));

    return result;
}

QVariantMap StarlingClient::loadStoredPhysicalCardFullAfterConfirmation()
{
    QVariantMap result;

    const QString json = m_tokenStore.loadPhysicalCard().trimmed();
    if (json.isEmpty()) {
        setPinSettingsError(QStringLiteral("No physical card stored."));
        return result;
    }

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        setPinSettingsError(QStringLiteral("Stored card data is invalid."));
        return QVariantMap{};
    }

    const QJsonObject obj = doc.object();
    result.insert(QStringLiteral("cardholderName"),
                  obj.value(QStringLiteral("cardholderName")).toString());
    result.insert(QStringLiteral("cardNumber"),
                  obj.value(QStringLiteral("cardNumber")).toString());
    result.insert(QStringLiteral("expiryMonth"),
                  obj.value(QStringLiteral("expiryMonth")).toString());
    result.insert(QStringLiteral("expiryYear"),
                  obj.value(QStringLiteral("expiryYear")).toString());

    clearPinSettingsError();
    return result;
}

bool StarlingClient::deleteStoredPhysicalCardAfterConfirmation()
{
    if (!m_tokenStore.clearPhysicalCard()) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to delete physical card: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("Failed to delete physical card."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

// PIN
bool StarlingClient::hasStoredPhysicalCardPin() const
{
    return !m_tokenStore.loadPhysicalCardPin().trimmed().isEmpty();
}

bool StarlingClient::savePhysicalCardPinAfterConfirmation(const QString &pin,
                                                          const QString &confirmPin)
{
    const QString cleanPin = pin.trimmed();
    const QString cleanConfirm = confirmPin.trimmed();

    if (cleanPin.isEmpty() || cleanConfirm.isEmpty()) {
        setPinSettingsError(QStringLiteral("Please enter and confirm the card PIN."));
        return false;
    }

    if (cleanPin != cleanConfirm) {
        setPinSettingsError(QStringLiteral("Card PIN and confirmation do not match."));
        return false;
    }

    for (int i = 0; i < cleanPin.length(); ++i) {
        if (!cleanPin.at(i).isDigit()) {
            setPinSettingsError(QStringLiteral("Card PIN must contain digits only."));
            return false;
        }
    }

    if (cleanPin.length() != 4) {
        setPinSettingsError(QStringLiteral("Card PIN must be exactly 4 digits."));
        return false;
    }

    if (!m_tokenStore.savePhysicalCardPin(cleanPin)) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to save card PIN: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("Failed to save card PIN."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

QString StarlingClient::loadStoredPhysicalCardPinAfterConfirmation()
{
    const QString pin = m_tokenStore.loadPhysicalCardPin().trimmed();
    if (pin.isEmpty()) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to load card PIN: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("No physical card PIN stored."));
        return QString();
    }

    clearPinSettingsError();
    return pin;
}

bool StarlingClient::deleteStoredPhysicalCardPinAfterConfirmation()
{
    if (!m_tokenStore.clearPhysicalCardPin()) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to delete card PIN: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("Failed to delete card PIN."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

// CVV
bool StarlingClient::hasStoredPhysicalCardCvv() const
{
    return !m_tokenStore.loadPhysicalCardCvv().trimmed().isEmpty();
}

bool StarlingClient::savePhysicalCardCvvAfterConfirmation(const QString &cvv)
{
    const QString cleanCvv = cvv.trimmed();

    if (cleanCvv.isEmpty()) {
        setPinSettingsError(QStringLiteral("Please enter the card CVV."));
        return false;
    }

    for (int i = 0; i < cleanCvv.length(); ++i) {
        if (!cleanCvv.at(i).isDigit()) {
            setPinSettingsError(QStringLiteral("Card CVV must contain digits only."));
            return false;
        }
    }

    if (cleanCvv.length() < 3 || cleanCvv.length() > 4) {
        setPinSettingsError(QStringLiteral("Card CVV must be 3 or 4 digits."));
        return false;
    }

    if (!m_tokenStore.savePhysicalCardCvv(cleanCvv)) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to save card CVV: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("Failed to save card CVV."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

QString StarlingClient::loadStoredPhysicalCardCvvAfterConfirmation()
{
    const QString cvv = m_tokenStore.loadPhysicalCardCvv().trimmed();
    if (cvv.isEmpty()) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to load card CVV: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("No physical card CVV stored."));
        return QString();
    }

    clearPinSettingsError();
    return cvv;
}

bool StarlingClient::deleteStoredPhysicalCardCvvAfterConfirmation()
{
    if (!m_tokenStore.clearPhysicalCardCvv()) {
        const QString detail = m_tokenStore.lastError().trimmed();
        if (!detail.isEmpty())
            setPinSettingsError(QStringLiteral("Failed to delete card CVV: %1").arg(detail));
        else
            setPinSettingsError(QStringLiteral("Failed to delete card CVV."));
        return false;
    }

    clearPinSettingsError();
    return true;
}

// Lock
int StarlingClient::autoLockMinutes() const
{
    return m_autoLockMinutes;
}

void StarlingClient::setAutoLockMinutes(int minutes)
{
    if (minutes < 1)
        minutes = 1;

    if (m_autoLockMinutes == minutes)
        return;

    m_autoLockMinutes = minutes;

    QSettings settings;
    settings.setValue(QStringLiteral("security/autoLockMinutes"), m_autoLockMinutes);

    m_relockTimer.setInterval(m_autoLockMinutes * 60 * 1000);

    if (!m_locked)
        startRelockTimer();

    emit autoLockMinutesChanged();
}

bool StarlingClient::lockOnBackground() const
{
    return m_lockOnBackground;
}

void StarlingClient::setLockOnBackground(bool value)
{
    if (m_lockOnBackground == value)
        return;

    m_lockOnBackground = value;

    QSettings settings;
    settings.setValue(QStringLiteral("security/lockOnBackground"), m_lockOnBackground);

    emit lockOnBackgroundChanged();
}

void StarlingClient::dismissConsentMessage()
{
    clearConsentState();
}

bool StarlingClient::consentPending() const
{
    return m_consentPending;
}

QString StarlingClient::consentMessage() const
{
    return m_consentMessage;
}

QVariantMap StarlingClient::payeeDetail() const
{
    return m_payeeDetail;
}

void StarlingClient::clearPayeeDetail()
{
    if (m_payeeDetail.isEmpty())
        return;

    m_payeeDetail.clear();
    emit payeeDetailChanged();
}

QString StarlingClient::navigationTarget() const
{
    return m_navigationTarget;
}

bool StarlingClient::locked() const
{
    return m_locked;
}

QVariantList StarlingClient::cards() const
{
    return m_cards;
}

QVariantList StarlingClient::payees() const
{
    return m_payees;
}

bool StarlingClient::initializing() const
{
    return m_initializing;
}

QString StarlingClient::token() const
{
    return m_token;
}

void StarlingClient::setLocked(bool value)
{
    if (m_locked == value)
        return;

    m_locked = value;
    emit lockedChanged();
}

void StarlingClient::setToken(const QString &token)
{
    const QString trimmed = token.trimmed();
    if (m_token == trimmed)
        return;

    m_token = trimmed;
    emit tokenChanged();
}

QString StarlingClient::accountUid() const
{
    return m_accountUid;
}

QString StarlingClient::categoryUid() const
{
    return m_categoryUid;
}

QString StarlingClient::availableBalance() const
{
    return m_availableBalance;
}

QString StarlingClient::clearedBalance() const
{
    return m_clearedBalance;
}

QString StarlingClient::currency() const
{
    return m_currency;
}

QString StarlingClient::status() const
{
    return m_status;
}

bool StarlingClient::busy() const
{
    return m_busy;
}

void StarlingClient::setConsentPending(bool pending)
{
    if (m_consentPending == pending)
        return;

    m_consentPending = pending;
    emit consentPendingChanged();
}

void StarlingClient::setConsentMessage(const QString &message)
{
    if (m_consentMessage == message)
        return;

    m_consentMessage = message;
    emit consentMessageChanged();
}

void StarlingClient::clearConsentState()
{
    setConsentPending(false);
    setConsentMessage(QString());
}

QString StarlingClient::payeeWriteToken() const
{
    return m_payeeWriteToken;
}

void StarlingClient::setPayeeWriteToken(const QString &token)
{
    const QString cleaned = token.trimmed();
    if (m_payeeWriteToken == cleaned)
        return;

    m_payeeWriteToken = cleaned;
    emit payeeWriteTokenChanged();
}

QString StarlingClient::apiKeyId() const
{
    return m_apiKeyId;
}

void StarlingClient::setApiKeyId(const QString &value)
{
    const QString cleaned = value.trimmed();
    if (m_apiKeyId == cleaned)
        return;

    m_apiKeyId = cleaned;
    emit apiKeyIdChanged();
}

QString StarlingClient::privateApiKeyPem() const
{
    return m_privateApiKeyPem;
}

void StarlingClient::setPrivateApiKeyPem(const QString &value)
{
    const QString cleaned = value.trimmed();
    if (m_privateApiKeyPem == cleaned)
        return;

    m_privateApiKeyPem = cleaned;
    emit privateApiKeyPemChanged();
}

void StarlingClient::savePayeeWriteToken()
{
    if (!m_tokenStore.savePayeeWriteToken(m_payeeWriteToken)) {
        setStatus(QStringLiteral("Failed to save payee-write token: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setStatus(QStringLiteral("Payee-write token saved securely."));
}

void StarlingClient::loadPayeeWriteToken()
{
    setPayeeWriteToken(m_tokenStore.loadPayeeWriteToken());
}

void StarlingClient::clearPayeeWriteToken()
{
    if (!m_tokenStore.clearPayeeWriteToken()) {
        setStatus(QStringLiteral("Failed to clear payee-write token: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setPayeeWriteToken(QString());
    setStatus(QStringLiteral("Payee-write token cleared."));
}

void StarlingClient::saveApiKeyId()
{
    if (!m_tokenStore.saveApiKeyId(m_apiKeyId)) {
        setStatus(QStringLiteral("Failed to save API key ID: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setStatus(QStringLiteral("API key ID saved securely."));
}

void StarlingClient::loadApiKeyId()
{
    setApiKeyId(m_tokenStore.loadApiKeyId());
}

void StarlingClient::clearApiKeyId()
{
    if (!m_tokenStore.clearApiKeyId()) {
        setStatus(QStringLiteral("Failed to clear API key ID: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setApiKeyId(QString());
    setStatus(QStringLiteral("API key ID cleared."));
}

void StarlingClient::savePrivateApiKeyPem()
{
    if (!m_tokenStore.savePrivateApiKeyPem(m_privateApiKeyPem)) {
        setStatus(QStringLiteral("Failed to save private API key: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setStatus(QStringLiteral("Private API key saved securely."));
}

void StarlingClient::loadPrivateApiKeyPem()
{
    setPrivateApiKeyPem(m_tokenStore.loadPrivateApiKeyPem());
}

void StarlingClient::clearPrivateApiKeyPem()
{
    if (!m_tokenStore.clearPrivateApiKeyPem()) {
        setStatus(QStringLiteral("Failed to clear private API key: %1")
                  .arg(m_tokenStore.lastError()));
        return;
    }

    setPrivateApiKeyPem(QString());
    setStatus(QStringLiteral("Private API key cleared."));
}

void StarlingClient::refreshPayeeDetail(const QString &payeeUid)
{
    if (payeeUid.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Missing payee UID."));
        return;
    }

    const QString path = QStringLiteral("/api/v2/payees/%1").arg(payeeUid);

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject obj = doc.object();

        QVariantMap row;
        row.insert(QStringLiteral("payeeUid"), obj.value(QStringLiteral("payeeUid")).toString());
        row.insert(QStringLiteral("payeeName"), obj.value(QStringLiteral("payeeName")).toString());
        row.insert(QStringLiteral("phoneNumber"), obj.value(QStringLiteral("phoneNumber")).toString());
        row.insert(QStringLiteral("payeeType"), obj.value(QStringLiteral("payeeType")).toString());
        row.insert(QStringLiteral("firstName"), obj.value(QStringLiteral("firstName")).toString());
        row.insert(QStringLiteral("middleName"), obj.value(QStringLiteral("middleName")).toString());
        row.insert(QStringLiteral("lastName"), obj.value(QStringLiteral("lastName")).toString());
        row.insert(QStringLiteral("businessName"), obj.value(QStringLiteral("businessName")).toString());
        row.insert(QStringLiteral("dateOfBirth"), obj.value(QStringLiteral("dateOfBirth")).toString());

        const QJsonArray accounts = obj.value(QStringLiteral("accounts")).toArray();
        QVariantList accountRows;

        for (int i = 0; i < accounts.size(); ++i) {
            const QJsonObject accObj = accounts.at(i).toObject();

            QVariantMap accountRow;
            accountRow.insert(QStringLiteral("payeeAccountUid"), accObj.value(QStringLiteral("payeeAccountUid")).toString());
            accountRow.insert(QStringLiteral("payeeChannelType"), accObj.value(QStringLiteral("payeeChannelType")).toString());
            accountRow.insert(QStringLiteral("description"), accObj.value(QStringLiteral("description")).toString());
            accountRow.insert(QStringLiteral("defaultAccount"), accObj.value(QStringLiteral("defaultAccount")).toBool());
            accountRow.insert(QStringLiteral("countryCode"), accObj.value(QStringLiteral("countryCode")).toString());
            accountRow.insert(QStringLiteral("accountIdentifier"), accObj.value(QStringLiteral("accountIdentifier")).toString());
            accountRow.insert(QStringLiteral("bankIdentifier"), formatSortCode(accObj.value(QStringLiteral("bankIdentifier")).toString()));
            accountRow.insert(QStringLiteral("bankIdentifierType"), accObj.value(QStringLiteral("bankIdentifierType")).toString());
            accountRow.insert(QStringLiteral("secondaryIdentifier"), accObj.value(QStringLiteral("secondaryIdentifier")).toString());

            const QJsonArray refs = accObj.value(QStringLiteral("lastReferences")).toArray();
            QVariantList refRows;
            for (int j = 0; j < refs.size(); ++j)
                refRows.append(refs.at(j).toString());

            accountRow.insert(QStringLiteral("lastReferences"), refRows);
            accountRows.append(accountRow);
        }

        row.insert(QStringLiteral("accounts"), accountRows);
        row.insert(QStringLiteral("accountCount"), accountRows.size());

        m_payeeDetail = row;
        emit payeeDetailChanged();
        setStatus(QStringLiteral("Payee details loaded."));
    });
}

bool StarlingClient::responseRequiresConsent(const QByteArray &body, QString *messageOut) const
{
    const QJsonDocument doc = QJsonDocument::fromJson(body);
    if (!doc.isObject())
        return false;

    const QJsonObject obj = doc.object();

    bool pending = false;

    if (obj.value(QStringLiteral("consentRequired")).toBool())
        pending = true;

    if (obj.value(QStringLiteral("approvalRequired")).toBool())
        pending = true;

    if (obj.contains(QStringLiteral("consentInformation")))
        pending = true;

    if (obj.contains(QStringLiteral("consentUid")))
        pending = true;

    if (!pending)
        return false;

    QString msg = QStringLiteral("Pending approval in Starling app.");

    const QJsonValue ci = obj.value(QStringLiteral("consentInformation"));
    if (ci.isObject()) {
        const QJsonObject cio = ci.toObject();
        if (!cio.value(QStringLiteral("message")).toString().trimmed().isEmpty())
            msg = cio.value(QStringLiteral("message")).toString().trimmed();
    }

    if (messageOut)
        *messageOut = msg;

    return true;
}

QString StarlingClient::buildIsoDateHeader() const
{
    const QDateTime now = QDateTime::currentDateTime();
    const int offsetSeconds = now.offsetFromUtc();
    const int offsetAbs = qAbs(offsetSeconds);
    const int offsetHours = offsetAbs / 3600;
    const int offsetMinutes = (offsetAbs % 3600) / 60;

    const QString offsetString = QStringLiteral("%1%2:%3")
            .arg(offsetSeconds >= 0 ? QStringLiteral("+") : QStringLiteral("-"))
            .arg(offsetHours, 2, 10, QLatin1Char('0'))
            .arg(offsetMinutes, 2, 10, QLatin1Char('0'));

    const int microsecondPart = now.time().msec() * 1000;

    return QStringLiteral("%1.%2%3")
            .arg(now.toString(QStringLiteral("yyyy-MM-dd'T'HH:mm:ss")))
            .arg(microsecondPart, 6, 10, QLatin1Char('0'))
            .arg(offsetString);
}

QByteArray StarlingClient::buildDigestHeader(const QByteArray &body) const
{
    const QByteArray hash = QCryptographicHash::hash(body, QCryptographicHash::Sha512);
    return hash.toBase64();
}

QByteArray StarlingClient::signWithRsaSha512(const QByteArray &content,
                                             const QString &privateKeyPem,
                                             QString *errorMessage) const
{
    if (errorMessage)
        errorMessage->clear();

    const QByteArray pemBytes = privateKeyPem.toUtf8();
    BIO *bio = BIO_new_mem_buf(pemBytes.constData(), pemBytes.size());
    if (!bio) {
        if (errorMessage)
            *errorMessage = QStringLiteral("Failed to create BIO for private key.");
        return QByteArray();
    }

    EVP_PKEY *pkey = PEM_read_bio_PrivateKey(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);

    if (!pkey) {
        if (errorMessage)
            *errorMessage = QStringLiteral("Failed to parse private API key PEM.");
        return QByteArray();
    }

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) {
        EVP_PKEY_free(pkey);
        if (errorMessage)
            *errorMessage = QStringLiteral("Failed to create signing context.");
        return QByteArray();
    }

    QByteArray signatureBase64;

    do {
        if (EVP_DigestSignInit(ctx, nullptr, EVP_sha512(), nullptr, pkey) != 1) {
            if (errorMessage)
                *errorMessage = QStringLiteral("EVP_DigestSignInit failed.");
            break;
        }

        if (EVP_DigestSignUpdate(ctx, content.constData(), size_t(content.size())) != 1) {
            if (errorMessage)
                *errorMessage = QStringLiteral("EVP_DigestSignUpdate failed.");
            break;
        }

        size_t signatureLen = 0;
        if (EVP_DigestSignFinal(ctx, nullptr, &signatureLen) != 1 || signatureLen == 0) {
            if (errorMessage)
                *errorMessage = QStringLiteral("Failed to determine signature length.");
            break;
        }

        QByteArray signature;
        signature.resize(int(signatureLen));

        if (EVP_DigestSignFinal(ctx,
                                reinterpret_cast<unsigned char *>(signature.data()),
                                &signatureLen) != 1) {
            if (errorMessage)
                *errorMessage = QStringLiteral("EVP_DigestSignFinal failed.");
            break;
        }

        signature.resize(int(signatureLen));
        signatureBase64 = signature.toBase64();
    } while (false);

    EVP_MD_CTX_free(ctx);
    EVP_PKEY_free(pkey);

    return signatureBase64;
}

void StarlingClient::sendJsonWithToken(const QString &path,
                                       const QString &httpMethod,
                                       const QJsonObject &payload,
                                       const QString &bearerToken,
                                       const std::function<void(const QByteArray &)> &onSuccess,
                                       bool includeDigestHeader)
{
    if (!m_online) {
        const QString msg = QStringLiteral("No internet connection.");
        setStatus(msg);

        if (includeDigestHeader) {
            setPaymentSubmitting(false);
            setPaymentSubmitted(false);
            setPaymentResultMessage(msg);
        }
        return;
    }

    if (bearerToken.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Authentication token is missing."));
        return;
    }

    beginRequest();

    QNetworkRequest req(QUrl(QString::fromLatin1(BASE_URL) + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", QByteArray("application/json"));

    const QByteArray body = QJsonDocument(payload).toJson(QJsonDocument::Compact);

    QByteArray authorizationHeader = QByteArray("Bearer ") + bearerToken.toUtf8();

    if (includeDigestHeader) {
        if (m_apiKeyId.trimmed().isEmpty()) {
            setStatus(QStringLiteral("API key ID is missing."));
            setPaymentSubmitting(false);
            setPaymentSubmitted(false);
            setPaymentResultMessage(QStringLiteral("API key ID is missing."));
            endRequest();
            return;
        }

        if (m_privateApiKeyPem.trimmed().isEmpty()) {
            setStatus(QStringLiteral("Private API key is missing."));
            setPaymentSubmitting(false);
            setPaymentSubmitted(false);
            setPaymentResultMessage(QStringLiteral("Private API key is missing."));
            endRequest();
            return;
        }

        const QByteArray digestValue = buildDigestHeader(body);
        const QString dateHeader = buildIsoDateHeader();

        req.setRawHeader("Digest", digestValue);
        req.setRawHeader("Date", dateHeader.toUtf8());

        const QString requestTarget = QStringLiteral("%1 %2")
                .arg(httpMethod.trimmed().toLower(), path);

        const QByteArray signingContent =
                QByteArray("(request-target): ") + requestTarget.toUtf8() + '\n' +
                QByteArray("Date: ") + dateHeader.toUtf8() + '\n' +
                QByteArray("Digest: ") + digestValue;

        QString signError;
        const QByteArray signatureBase64 =
                signWithRsaSha512(signingContent, m_privateApiKeyPem, &signError);

        if (signatureBase64.isEmpty()) {
            const QString msg = signError.isEmpty()
                    ? QStringLiteral("Failed to sign payment request.")
                    : signError;
            setStatus(msg);
            setPaymentSubmitting(false);
            setPaymentSubmitted(false);
            setPaymentResultMessage(msg);
            endRequest();
            return;
        }

        authorizationHeader += QByteArray(";Signature keyid=\"")
                + m_apiKeyId.toUtf8()
                + QByteArray("\",algorithm=\"rsa-sha512\",headers=\"(request-target) Date Digest\",signature=\"")
                + signatureBase64
                + QByteArray("\"");
    }

    req.setRawHeader("Authorization", authorizationHeader);

    QBuffer *buffer = new QBuffer;
    buffer->setData(body);
    buffer->open(QIODevice::ReadOnly);

    QNetworkReply *reply = m_nam.sendCustomRequest(req, httpMethod.toUtf8(), buffer);
    buffer->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
        const int statusCode =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        const QByteArray responseBody = reply->readAll();

        const QString qtError =
                reply->error() == QNetworkReply::NoError ? QString() : reply->errorString();
        const QString bodyText = QString::fromUtf8(responseBody).trimmed();

        if (reply->error() != QNetworkReply::NoError) {
            QString msg = QStringLiteral("HTTP %1").arg(statusCode);
            if (!qtError.isEmpty())
                msg += QStringLiteral(" | Qt: %1").arg(qtError);
            if (!bodyText.isEmpty())
                msg += QStringLiteral(" | Body: %1").arg(bodyText);

            qWarning() << "sendJsonWithToken failed"
                       << "url=" << reply->url()
                       << "status=" << statusCode
                       << "qtError=" << qtError
                       << "body=" << bodyText;

            setStatus(msg);
            setPaymentSubmitting(false);
            setPaymentSubmitted(false);
            setPaymentResultMessage(msg);
            endRequest();
            reply->deleteLater();
            return;
        }

        QString consentMsg;
        if (responseRequiresConsent(responseBody, &consentMsg)) {
            setConsentPending(true);
            setConsentMessage(consentMsg);
            setStatus(consentMsg);
        } else {
            clearConsentState();
        }

        onSuccess(responseBody);
        endRequest();
        reply->deleteLater();
    });
}

void StarlingClient::sendDeleteWithToken(const QString &path,
                                         const QString &bearerToken,
                                         const std::function<void(const QByteArray &)> &onSuccess)
{
    if (!m_online) {
        setStatus(QStringLiteral("No internet connection."));
        return;
    }

    if (bearerToken.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Missing payee-write token."));
        return;
    }

    beginRequest();

    QNetworkRequest req(QUrl(QString::fromLatin1(BASE_URL) + path));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + bearerToken.toUtf8());

    QNetworkReply *reply = m_nam.deleteResource(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
        const int statusCode =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        const QByteArray responseBody = reply->readAll();

        const QString qtError =
                reply->error() == QNetworkReply::NoError ? QString() : reply->errorString();
        const QString bodyText = QString::fromUtf8(responseBody).trimmed();

        if (reply->error() != QNetworkReply::NoError) {
            QString msg = QStringLiteral("HTTP %1").arg(statusCode);
            if (!qtError.isEmpty())
                msg += QStringLiteral(" | Qt: %1").arg(qtError);
            if (!bodyText.isEmpty())
                msg += QStringLiteral(" | Body: %1").arg(bodyText);

            qWarning() << "sendJsonWithToken failed"
                       << "url=" << reply->url()
                       << "status=" << statusCode
                       << "qtError=" << qtError
                       << "body=" << bodyText;

            setStatus(msg);
            endRequest();
            reply->deleteLater();
            return;
        }

        QString consentMsg;
        if (responseRequiresConsent(responseBody, &consentMsg)) {
            setConsentPending(true);
            setConsentMessage(consentMsg);
            setStatus(consentMsg);
        } else {
            clearConsentState();
        }

        onSuccess(responseBody);
        endRequest();
        reply->deleteLater();
    });
}

QJsonObject StarlingClient::buildPayeeAccountObject(const QString &accountDescription,
                                                    bool defaultAccount,
                                                    const QString &countryCode,
                                                    const QString &accountIdentifier,
                                                    const QString &bankIdentifier,
                                                    const QString &bankIdentifierType,
                                                    const QString &secondaryIdentifier) const
{
    QJsonObject obj;
    obj.insert(QStringLiteral("description"), accountDescription);
    obj.insert(QStringLiteral("defaultAccount"), defaultAccount);
    obj.insert(QStringLiteral("countryCode"), countryCode);
    obj.insert(QStringLiteral("accountIdentifier"), accountIdentifier);
    obj.insert(QStringLiteral("bankIdentifier"), bankIdentifier);
    obj.insert(QStringLiteral("bankIdentifierType"), bankIdentifierType);

    if (!secondaryIdentifier.trimmed().isEmpty())
        obj.insert(QStringLiteral("secondaryIdentifier"), secondaryIdentifier.trimmed());

    return obj;
}

QJsonObject StarlingClient::buildPayeeObject(const QString &payeeName,
                                             const QString &phoneNumber,
                                             const QString &payeeType,
                                             const QString &firstName,
                                             const QString &middleName,
                                             const QString &lastName,
                                             const QString &businessName,
                                             const QString &dateOfBirth,
                                             const QString &accountDescription,
                                             bool defaultAccount,
                                             const QString &countryCode,
                                             const QString &accountIdentifier,
                                             const QString &bankIdentifier,
                                             const QString &bankIdentifierType,
                                             const QString &secondaryIdentifier) const
{
    QJsonObject obj;
    obj.insert(QStringLiteral("payeeName"), payeeName.trimmed());
    obj.insert(QStringLiteral("payeeType"), payeeType.trimmed());

    if (!phoneNumber.trimmed().isEmpty())
        obj.insert(QStringLiteral("phoneNumber"), phoneNumber.trimmed());
    if (!firstName.trimmed().isEmpty())
        obj.insert(QStringLiteral("firstName"), firstName.trimmed());
    if (!middleName.trimmed().isEmpty())
        obj.insert(QStringLiteral("middleName"), middleName.trimmed());
    if (!lastName.trimmed().isEmpty())
        obj.insert(QStringLiteral("lastName"), lastName.trimmed());
    if (!businessName.trimmed().isEmpty())
        obj.insert(QStringLiteral("businessName"), businessName.trimmed());
    if (!dateOfBirth.trimmed().isEmpty())
        obj.insert(QStringLiteral("dateOfBirth"), dateOfBirth.trimmed());

    QJsonArray accounts;
    accounts.append(buildPayeeAccountObject(accountDescription,
                                           defaultAccount,
                                           countryCode,
                                           accountIdentifier,
                                           bankIdentifier,
                                           bankIdentifierType,
                                           secondaryIdentifier));
    obj.insert(QStringLiteral("accounts"), accounts);

    return obj;
}

void StarlingClient::createPayee(const QString &payeeName,
                                 const QString &phoneNumber,
                                 const QString &payeeType,
                                 const QString &firstName,
                                 const QString &middleName,
                                 const QString &lastName,
                                 const QString &businessName,
                                 const QString &dateOfBirth,
                                 const QString &accountDescription,
                                 bool defaultAccount,
                                 const QString &countryCode,
                                 const QString &accountIdentifier,
                                 const QString &bankIdentifier,
                                 const QString &bankIdentifierType,
                                 const QString &secondaryIdentifier)
{
    const QJsonObject payload = buildPayeeObject(payeeName, phoneNumber, payeeType,
                                                 firstName, middleName, lastName,
                                                 businessName, dateOfBirth,
                                                 accountDescription, defaultAccount,
                                                 countryCode, accountIdentifier,
                                                 bankIdentifier, bankIdentifierType,
                                                 secondaryIdentifier);

    sendJsonWithToken(QStringLiteral("/api/v2/payees"),
                      QStringLiteral("PUT"),
                      payload,
                      m_payeeWriteToken,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Payee created."));
        refreshPayees();
    });
}

void StarlingClient::createPayeeAccount(const QString &payeeUid,
                                        const QString &accountDescription,
                                        bool defaultAccount,
                                        const QString &countryCode,
                                        const QString &accountIdentifier,
                                        const QString &bankIdentifier,
                                        const QString &bankIdentifierType,
                                        const QString &secondaryIdentifier)
{
    const QString path = QStringLiteral("/api/v2/payees/%1/account").arg(payeeUid);
    const QJsonObject payload = buildPayeeAccountObject(accountDescription,
                                                        defaultAccount,
                                                        countryCode,
                                                        accountIdentifier,
                                                        bankIdentifier,
                                                        bankIdentifierType,
                                                        secondaryIdentifier);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_payeeWriteToken,
                      [this, payeeUid](const QByteArray &) {
        setStatus(QStringLiteral("Payee account created."));
        refreshPayees();
        refreshPayeeDetail(payeeUid);
    });
}

void StarlingClient::updatePayee(const QString &payeeUid,
                                 const QString &payeeName,
                                 const QString &phoneNumber,
                                 const QString &payeeType,
                                 const QString &firstName,
                                 const QString &middleName,
                                 const QString &lastName,
                                 const QString &businessName,
                                 const QString &dateOfBirth,
                                 const QString &accountDescription,
                                 bool defaultAccount,
                                 const QString &countryCode,
                                 const QString &accountIdentifier,
                                 const QString &bankIdentifier,
                                 const QString &bankIdentifierType,
                                 const QString &secondaryIdentifier)
{
    const QString path = QStringLiteral("/api/v2/payees/%1").arg(payeeUid);
    const QJsonObject payload = buildPayeeObject(payeeName, phoneNumber, payeeType,
                                                 firstName, middleName, lastName,
                                                 businessName, dateOfBirth,
                                                 accountDescription, defaultAccount,
                                                 countryCode, accountIdentifier,
                                                 bankIdentifier, bankIdentifierType,
                                                 secondaryIdentifier);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this](const QByteArray &) {
        if (!m_consentPending)
            setStatus(QStringLiteral("Payee updated."));
        refreshPayees();
    });
}

void StarlingClient::updatePayeeNames(const QString &payeeUid,
                                      const QString &payeeName,
                                      const QString &firstName,
                                      const QString &middleName,
                                      const QString &lastName)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    if (payeeUid.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Missing payee UID."));
        return;
    }

    if (m_payeeDetail.isEmpty()) {
        setStatus(QStringLiteral("Payee details not loaded."));
        return;
    }

    const QString detailUid = m_payeeDetail.value(QStringLiteral("payeeUid")).toString();
    if (detailUid != payeeUid) {
        setStatus(QStringLiteral("Loaded payee details do not match requested payee."));
        return;
    }

    QJsonObject payload;
    payload.insert(QStringLiteral("payeeName"), payeeName.trimmed());
    payload.insert(QStringLiteral("payeeType"),
                   m_payeeDetail.value(QStringLiteral("payeeType")).toString());

    const QString phoneNumber =
            m_payeeDetail.value(QStringLiteral("phoneNumber")).toString().trimmed();
    if (!phoneNumber.isEmpty())
        payload.insert(QStringLiteral("phoneNumber"), phoneNumber);

    const QString payeeType =
            m_payeeDetail.value(QStringLiteral("payeeType")).toString();

    if (payeeType == QStringLiteral("BUSINESS")) {
        const QString businessName =
                m_payeeDetail.value(QStringLiteral("businessName")).toString().trimmed();
        if (!businessName.isEmpty())
            payload.insert(QStringLiteral("businessName"), businessName);
    } else {
        if (!firstName.trimmed().isEmpty())
            payload.insert(QStringLiteral("firstName"), firstName.trimmed());

        if (!middleName.trimmed().isEmpty())
            payload.insert(QStringLiteral("middleName"), middleName.trimmed());

        if (!lastName.trimmed().isEmpty())
            payload.insert(QStringLiteral("lastName"), lastName.trimmed());

        const QString dateOfBirth =
                m_payeeDetail.value(QStringLiteral("dateOfBirth")).toString().trimmed();
        if (!dateOfBirth.isEmpty())
            payload.insert(QStringLiteral("dateOfBirth"), dateOfBirth);
    }

    QJsonArray accountsArray;
    const QVariantList accounts =
            m_payeeDetail.value(QStringLiteral("accounts")).toList();

    for (const QVariant &accVar : accounts) {
        const QVariantMap acc = accVar.toMap();

        QJsonObject accObj;
        accObj.insert(QStringLiteral("description"),
                      acc.value(QStringLiteral("description")).toString());
        accObj.insert(QStringLiteral("defaultAccount"),
                      acc.value(QStringLiteral("defaultAccount")).toBool());
        accObj.insert(QStringLiteral("countryCode"),
                      acc.value(QStringLiteral("countryCode")).toString());
        accObj.insert(QStringLiteral("accountIdentifier"),
                      acc.value(QStringLiteral("accountIdentifier")).toString());

        QString bankIdentifier =
                acc.value(QStringLiteral("bankIdentifier")).toString();
        bankIdentifier.remove('-');   // important if sort code is formatted for display
        accObj.insert(QStringLiteral("bankIdentifier"), bankIdentifier);

        accObj.insert(QStringLiteral("bankIdentifierType"),
                      acc.value(QStringLiteral("bankIdentifierType")).toString());

        const QString secondaryIdentifier =
                acc.value(QStringLiteral("secondaryIdentifier")).toString().trimmed();
        if (!secondaryIdentifier.isEmpty())
            accObj.insert(QStringLiteral("secondaryIdentifier"), secondaryIdentifier);

        accountsArray.append(accObj);
    }

    if (accountsArray.isEmpty()) {
        setStatus(QStringLiteral("Cannot update payee without at least one account."));
        return;
    }

    payload.insert(QStringLiteral("accounts"), accountsArray);

    const QString path = QStringLiteral("/api/v2/payees/%1").arg(payeeUid);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this, payeeUid](const QByteArray &) {
        if (!m_consentPending)
            setStatus(QStringLiteral("Payee updated."));
        refreshPayees();
        refreshPayeeDetail(payeeUid);
    });
}

void StarlingClient::deletePayee(const QString &payeeUid)
{

    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    const QString path = QStringLiteral("/api/v2/payees/%1").arg(payeeUid);

    sendDeleteWithToken(path,
                        m_token,
                        [this, payeeUid](const QByteArray &) {
        if (!m_consentPending)
            setStatus(QStringLiteral("Payee deleted."));
        refreshPayees();
        clearPayeeDetail();
        emit payeeDeleted(payeeUid);
    });
}

void StarlingClient::updatePayeeAccountDescription(const QString &payeeUid,
                                                   const QString &payeeAccountUid,
                                                   const QString &description)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    if (payeeUid.trimmed().isEmpty() || payeeAccountUid.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Missing payee or account UID."));
        return;
    }

    if (m_payeeDetail.isEmpty()) {
        setStatus(QStringLiteral("Payee details not loaded."));
        return;
    }

    const QString detailUid = m_payeeDetail.value(QStringLiteral("payeeUid")).toString();
    if (detailUid != payeeUid) {
        setStatus(QStringLiteral("Loaded payee details do not match requested payee."));
        return;
    }

    QJsonObject payload;
    payload.insert(QStringLiteral("payeeName"),
                   m_payeeDetail.value(QStringLiteral("payeeName")).toString().trimmed());
    payload.insert(QStringLiteral("payeeType"),
                   m_payeeDetail.value(QStringLiteral("payeeType")).toString());

    const QString phoneNumber =
            m_payeeDetail.value(QStringLiteral("phoneNumber")).toString().trimmed();
    if (!phoneNumber.isEmpty())
        payload.insert(QStringLiteral("phoneNumber"), phoneNumber);

    const QString payeeType =
            m_payeeDetail.value(QStringLiteral("payeeType")).toString();

    if (payeeType == QStringLiteral("BUSINESS")) {
        const QString businessName =
                m_payeeDetail.value(QStringLiteral("businessName")).toString().trimmed();
        if (!businessName.isEmpty())
            payload.insert(QStringLiteral("businessName"), businessName);
    } else {
        const QString firstName =
                m_payeeDetail.value(QStringLiteral("firstName")).toString().trimmed();
        const QString middleName =
                m_payeeDetail.value(QStringLiteral("middleName")).toString().trimmed();
        const QString lastName =
                m_payeeDetail.value(QStringLiteral("lastName")).toString().trimmed();
        const QString dateOfBirth =
                m_payeeDetail.value(QStringLiteral("dateOfBirth")).toString().trimmed();

        if (!firstName.isEmpty())
            payload.insert(QStringLiteral("firstName"), firstName);
        if (!middleName.isEmpty())
            payload.insert(QStringLiteral("middleName"), middleName);
        if (!lastName.isEmpty())
            payload.insert(QStringLiteral("lastName"), lastName);
        if (!dateOfBirth.isEmpty())
            payload.insert(QStringLiteral("dateOfBirth"), dateOfBirth);
    }

    QJsonArray accountsArray;
    const QVariantList accounts =
            m_payeeDetail.value(QStringLiteral("accounts")).toList();

    bool foundTarget = false;

    for (const QVariant &accVar : accounts) {
        const QVariantMap acc = accVar.toMap();
        const QString currentUid =
                acc.value(QStringLiteral("payeeAccountUid")).toString();

        QJsonObject accObj;
        accObj.insert(QStringLiteral("description"),
                      currentUid == payeeAccountUid
                          ? description.trimmed()
                          : acc.value(QStringLiteral("description")).toString());

        accObj.insert(QStringLiteral("defaultAccount"),
                      acc.value(QStringLiteral("defaultAccount")).toBool());
        accObj.insert(QStringLiteral("countryCode"),
                      acc.value(QStringLiteral("countryCode")).toString());
        accObj.insert(QStringLiteral("accountIdentifier"),
                      acc.value(QStringLiteral("accountIdentifier")).toString());

        QString bankIdentifier =
                acc.value(QStringLiteral("bankIdentifier")).toString();
        bankIdentifier.remove('-');
        accObj.insert(QStringLiteral("bankIdentifier"), bankIdentifier);

        accObj.insert(QStringLiteral("bankIdentifierType"),
                      acc.value(QStringLiteral("bankIdentifierType")).toString());

        const QString secondaryIdentifier =
                acc.value(QStringLiteral("secondaryIdentifier")).toString().trimmed();
        if (!secondaryIdentifier.isEmpty())
            accObj.insert(QStringLiteral("secondaryIdentifier"), secondaryIdentifier);

        accountsArray.append(accObj);

        if (currentUid == payeeAccountUid)
            foundTarget = true;
    }

    if (!foundTarget) {
        setStatus(QStringLiteral("Target payee account not found."));
        return;
    }

    if (accountsArray.isEmpty()) {
        setStatus(QStringLiteral("Cannot update payee without at least one account."));
        return;
    }

    payload.insert(QStringLiteral("accounts"), accountsArray);

    const QString path = QStringLiteral("/api/v2/payees/%1").arg(payeeUid);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this, payeeUid](const QByteArray &) {
        if (!m_consentPending)
            setStatus(QStringLiteral("Payee account updated."));
        refreshPayees();
        refreshPayeeDetail(payeeUid);
    });
}

void StarlingClient::deletePayeeAccount(const QString &payeeUid, const QString &accountUid)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    const QString path = QStringLiteral("/api/v2/payees/%1/account/%2")
            .arg(payeeUid, accountUid);

    sendDeleteWithToken(path,
                        m_token,
                        [this, payeeUid](const QByteArray &) {
        setStatus(QStringLiteral("Payee account deleted."));
        refreshPayees();
        refreshPayeeDetail(payeeUid);
    });
}

void StarlingClient::refreshSourceAccountIdentifiers(const QString &accountUid)
{
    if (accountUid.trimmed().isEmpty())
        return;

    const QString identifiersPath =
            QString("/api/v2/accounts/%1/identifiers").arg(accountUid);

    getJson(identifiersPath, [this, accountUid](const QByteArray &idBody) {
        const QJsonDocument idDoc = QJsonDocument::fromJson(idBody);
        const QJsonObject idRoot = idDoc.object();

        QString accountNumber = idRoot.value("accountIdentifier").toString();
        QString sortCode = idRoot.value("bankIdentifier").toString();

        const QJsonArray ids = idRoot.value("accountIdentifiers").toArray();
        for (int i = 0; i < ids.size(); ++i) {
            const QJsonObject obj = ids.at(i).toObject();
            const QString type = obj.value("identifierType").toString();
            const QString bankId = obj.value("bankIdentifier").toString();
            const QString acctId = obj.value("accountIdentifier").toString();

            if (type == "SORT_CODE") {
                if (!bankId.isEmpty())
                    sortCode = bankId;
                if (!acctId.isEmpty())
                    accountNumber = acctId;
            }
        }

        const QString formattedSortCode = formatSortCode(sortCode);

        bool changed = false;
        for (int i = 0; i < m_sourceAccounts.size(); ++i) {
            QVariantMap row = m_sourceAccounts.at(i).toMap();
            if (row.value(QStringLiteral("accountUid")).toString() == accountUid) {
                row.insert(QStringLiteral("accountNumber"), accountNumber);
                row.insert(QStringLiteral("sortCode"), formattedSortCode);
                m_sourceAccounts[i] = row;
                changed = true;
                break;
            }
        }

        if (changed)
            emit sourceAccountsChanged();

        if (accountUid == m_accountUid) {
            m_accountNumber = accountNumber;
            m_sortCode = formattedSortCode;
            emit accountChanged();
        }
    });
}

void StarlingClient::setNavigationTarget(const QString &target)
{
    if (m_navigationTarget == target)
        return;

    m_navigationTarget = target;
    emit navigationTargetChanged();
}

void StarlingClient::clearNavigationTarget()
{
    setNavigationTarget(QString());
}

void StarlingClient::requestOpenSettings()
{
    if (m_locked) {
        m_pendingAction = QStringLiteral("openSettings");
        unlock();
        return;
    }

    setNavigationTarget(QStringLiteral("Settings"));
}

QVariantList StarlingClient::transactionRows() const
{
    return m_transactionRows;
}

void StarlingClient::beginRequest()
{
    ++m_pendingRequests;
    setBusy(m_pendingRequests > 0);
}

void StarlingClient::lock()
{
    if (m_token.isEmpty() && m_locked)
        return;

    setToken(QString());
    setLocked(true);

    setInitializing(false);
    m_pendingRequests = 0;
    setBusy(false);

    clearTransactions();
    clearPayees();
    clearPayeeDetail();
    clearCards();
    setPayeeWriteToken(QString());
    setApiKeyId(QString());
    setPrivateApiKeyPem(QString());

    m_availableBalance.clear();
    m_clearedBalance.clear();
    m_currency.clear();
    emit balanceChanged();
    clearConsentState();

    setPinError(QString());
    setPinPromptVisible(false);

    setStatus(QStringLiteral("Locked."));
    stopRelockTimer();
}

void StarlingClient::continuePendingAction()
{
    const QString action = m_pendingAction;
    m_pendingAction.clear();

    if (action == QStringLiteral("refreshAll")) {
        refreshAll(m_startupDaysBack);
        return;
    }

    if (action == QStringLiteral("openSettings")) {
        setNavigationTarget(QStringLiteral("Settings"));
        return;
    }
}

void StarlingClient::startRelockTimer()
{
    if (m_locked)
        return;

    m_relockTimer.start(m_autoLockMinutes * 60 * 1000);
}

void StarlingClient::registerUserActivity()
{
    if (m_locked)
        return;

    startRelockTimer();
}

void StarlingClient::stopRelockTimer()
{
    m_relockTimer.stop();
}

void StarlingClient::performUnlock()
{
    const QString storedToken = m_tokenStore.loadToken();

    if (storedToken.isEmpty()) {
        setLocked(false);
        setStatus(QStringLiteral("No Personal Access Token saved."));
        return;
    }

    setToken(storedToken);
    setPayeeWriteToken(m_tokenStore.loadPayeeWriteToken());
    setApiKeyId(m_tokenStore.loadApiKeyId());
    setPrivateApiKeyPem(m_tokenStore.loadPrivateApiKeyPem());

    setLocked(false);
    setStatus(QStringLiteral("Unlocked."));
    startRelockTimer();

    if (!m_pendingAction.isEmpty()) {
        continuePendingAction();
    } else {
        refreshAll(m_startupDaysBack);
    }
}

void StarlingClient::unlock()
{
    if (pinEnabled()) {
        setPinError(QString());
        setPinPromptVisible(true);
        return;
    }

    performUnlock();
}

bool StarlingClient::submitPin(const QString &pin)
{
    if (!pinEnabled()) {
        performUnlock();
        return true;
    }

    if (!verifyPinValue(pin.trimmed())) {
        setPinError(QStringLiteral("Incorrect PIN."));
        return false;
    }

    setPinError(QString());
    setPinPromptVisible(false);

    if (m_pinConfirmationPending) {
        clearPinConfirmation();
        emit pinConfirmed();
        return true;
    }

    performUnlock();
    return true;
}

bool StarlingClient::changeAppPinAfterConfirmation(const QString &newPin,
                                                   const QString &confirmPin)
{
    if (!pinEnabled()) {
        setPinSettingsError(QStringLiteral("No app PIN is enabled."));
        return false;
    }

    QString error;
    if (!validateNewPin(newPin, confirmPin, &error)) {
        setPinSettingsError(error);
        return false;
    }

    m_pinSalt = QUuid::createUuid().toString().remove('{').remove('}');
    m_pinHash = hashPin(newPin.trimmed(), m_pinSalt);

    QSettings settings;
    settings.setValue(QStringLiteral("security/pinSalt"), m_pinSalt);
    settings.setValue(QStringLiteral("security/pinHash"), m_pinHash);

    setPinSettingsError(QString());
    setStatus(QStringLiteral("App PIN changed."));
    return true;
}

void StarlingClient::cancelPinPrompt()
{
    setPinError(QString());
    setPinPromptVisible(false);
    clearPinConfirmation();
}

bool StarlingClient::setAppPin(const QString &pin, const QString &confirmPin)
{
    QString error;
    if (!validateNewPin(pin, confirmPin, &error)) {
        setPinSettingsError(error);
        return false;
    }

    const bool wasEnabled = pinEnabled();

    m_pinSalt = QUuid::createUuid().toString().remove('{').remove('}');
    m_pinHash = hashPin(pin.trimmed(), m_pinSalt);

    QSettings settings;
    settings.setValue(QStringLiteral("security/pinSalt"), m_pinSalt);
    settings.setValue(QStringLiteral("security/pinHash"), m_pinHash);

    if (!wasEnabled)
        emit pinEnabledChanged();

    setPinSettingsError(QStringLiteral("App PIN enabled."));
    emit pinEnabledChanged();
    emit pinSetupRequiredChanged();
    return true;
}

bool StarlingClient::changeAppPin(const QString &currentPin,
                                  const QString &newPin,
                                  const QString &confirmPin)
{
    if (!pinEnabled()) {
        setPinSettingsError(QStringLiteral("No app PIN is enabled."));
        return false;
    }

    if (!verifyPinValue(currentPin.trimmed())) {
        setPinSettingsError(QStringLiteral("Current PIN is incorrect."));
        return false;
    }

    QString error;
    if (!validateNewPin(newPin, confirmPin, &error)) {
        setPinSettingsError(error);
        return false;
    }

    m_pinSalt = QUuid::createUuid().toString().remove('{').remove('}');
    m_pinHash = hashPin(newPin.trimmed(), m_pinSalt);

    QSettings settings;
    settings.setValue(QStringLiteral("security/pinSalt"), m_pinSalt);
    settings.setValue(QStringLiteral("security/pinHash"), m_pinHash);

    setPinSettingsError(QStringLiteral("App PIN changed."));
    return true;
}

void StarlingClient::clearPinError()
{
    setPinError(QString());
}

QString StarlingClient::pinSettingsError() const
{
    return m_pinSettingsError;
}

void StarlingClient::setPinSettingsError(const QString &value)
{
    if (m_pinSettingsError == value)
        return;

    m_pinSettingsError = value;
    emit pinSettingsErrorChanged();
}

void StarlingClient::clearPinSettingsError()
{
    setPinSettingsError(QString());
}

bool StarlingClient::pinSetupRequired() const
{
    return !pinEnabled();
}

void StarlingClient::refreshAll(int daysBack)
{
    m_startupDaysBack = daysBack;

    if (m_locked || m_token.isEmpty()) {
        m_pendingAction = QStringLiteral("refreshAll");
        unlock();
        return;
    }

    if (!m_online) {
        setStatus(QStringLiteral("No internet connection."));
        setInitializing(false);
        setBusy(false);
        return;
    }

    setInitializing(true);
    setStatus(QStringLiteral("Loading account..."));

    // stage 1
    discoverAccount();
}

void StarlingClient::endRequest()
{
    if (m_pendingRequests > 0)
        --m_pendingRequests;

    setBusy(m_pendingRequests > 0);

    if (m_initializing && m_pendingRequests == 0) {
        setInitializing(false);

        if (!m_accountUid.isEmpty() && !m_categoryUid.isEmpty())
            setStatus(QStringLiteral("Ready."));
    }
}

void StarlingClient::setInitializing(bool value)
{
    if (m_initializing == value)
        return;

    m_initializing = value;
    emit initializingChanged();
}

void StarlingClient::resetLoadedData()
{
    m_accountUid.clear();
    m_categoryUid.clear();
    m_availableBalance.clear();
    m_clearedBalance.clear();
    m_currency.clear();
    m_transactionRows.clear();
    m_lastUpdated.clear();

    m_accountHolderName.clear();
    m_accountName.clear();
    m_accountNumber.clear();
    m_sortCode.clear();
    m_accountType.clear();
    m_email.clear();
    m_phone.clear();
    m_postalAddress.clear();
    m_countryCode.clear();
    m_sourceAccounts.clear();

    emit accountChanged();
    emit balanceChanged();
    emit transactionsChanged();
    emit lastUpdatedChanged();
    emit sourceAccountsChanged();
}

void StarlingClient::initialize(int daysBack)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Missing token."));
        return;
    }

    if (!m_online) {
        m_startupDaysBack = daysBack;
        m_pendingRequests = 0;
        setBusy(false);
        setInitializing(false);
        setStatus(QStringLiteral("No internet connection."));
        return;
    }

    m_startupDaysBack = daysBack;
    m_pendingRequests = 0;
    setBusy(false);
    setInitializing(true);
    setStatus(QStringLiteral("Loading account..."));

    resetLoadedData();
    discoverAccount();
}

QVariantList StarlingClient::recentTransactions() const
{
    QVariantList out;
    for (int i = 0; i < m_transactionRows.size(); ++i) {
        const QVariantMap row = m_transactionRows.at(i).toMap();
        if (row.value("rowType").toString() != QStringLiteral("transaction"))
            continue;
        out.append(row);
        if (out.size() >= 3)
            break;
    }
    return out;
}

QString StarlingClient::lastUpdated() const
{
    return m_lastUpdated;
}

QString StarlingClient::accountHolderName() const
{
    return m_accountHolderName;
}

QString StarlingClient::accountName() const
{
    return m_accountName;
}

QString StarlingClient::accountNumber() const
{
    return m_accountNumber;
}

QString StarlingClient::sortCode() const
{
    return m_sortCode;
}

QString StarlingClient::accountType() const
{
    return m_accountType;
}

QString StarlingClient::email() const
{
    return m_email;
}

QString StarlingClient::phone() const
{
    return m_phone;
}

QString StarlingClient::postalAddress() const
{
    return m_postalAddress;
}

QString StarlingClient::countryCode() const
{
    return m_countryCode;
}

// Network
bool StarlingClient::online() const
{
    return m_online;
}

void StarlingClient::setOnline(bool value)
{
    if (m_online == value)
        return;

    m_online = value;
    emit onlineChanged();
}

void StarlingClient::setBusy(bool value)
{
    if (m_busy == value)
        return;

    m_busy = value;
    emit busyChanged();
}

void StarlingClient::setStatus(const QString &value)
{
    if (m_status == value)
        return;

    m_status = value;
    emit statusChanged();
}

void StarlingClient::clearCards()
{
    if (m_cards.isEmpty())
        return;

    m_cards.clear();
    emit cardsChanged();
}

void StarlingClient::clearTransactions()
{
    if (m_transactionRows.isEmpty())
        return;

    m_transactionRows.clear();
    emit transactionsChanged();
}

void StarlingClient::clearPayees()
{
    if (m_payees.isEmpty())
        return;

    m_payees.clear();
    emit payeesChanged();
}

void StarlingClient::touchLastUpdated()
{
    const QString value = QDateTime::currentDateTime().toString("dd MMM yyyy hh:mm");
    if (m_lastUpdated == value)
        return;

    m_lastUpdated = value;
    emit lastUpdatedChanged();
}

void StarlingClient::saveToken()
{
    if (!m_tokenStore.saveToken(m_token)) {
        setStatus(QString("Failed to save token: %1").arg(m_tokenStore.lastError()));
        return;
    }

    setLocked(false);
    setStatus(QStringLiteral("Token saved securely."));
    refreshAll(m_startupDaysBack);
}

void StarlingClient::loadToken()
{
    const QString storedToken = m_tokenStore.loadToken();

    if (storedToken.isEmpty() && !m_tokenStore.lastError().isEmpty()) {
        setStatus(QString("Failed to load token: %1").arg(m_tokenStore.lastError()));
        return;
    }

    setToken(storedToken);
}

void StarlingClient::clearToken()
{
    if (!m_tokenStore.clearToken()) {
        setStatus(QString("Failed to clear token: %1").arg(m_tokenStore.lastError()));
        return;
    }

    setToken(QString());

    // End the authenticated session data, but do not hard-lock the app.
    resetLoadedData();
    clearTransactions();
    clearPayees();
    clearPayeeDetail();
    clearCards();
    clearConsentState();
    clearPaymentDraft();
    clearPaymentResult();

    setStatus(QStringLiteral("Personal Access Token cleared."));
}

void StarlingClient::refreshCards()
{
    const QString path = QStringLiteral("/api/v2/cards");

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();
        const QJsonArray cardsArray = root.value(QStringLiteral("cards")).toArray();

        QVariantList rows;
        rows.reserve(cardsArray.size());

        for (int i = 0; i < cardsArray.size(); ++i) {
            const QJsonObject obj = cardsArray.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("cardUid"), obj.value(QStringLiteral("cardUid")).toString());
            row.insert(QStringLiteral("publicToken"), obj.value(QStringLiteral("publicToken")).toString());
            row.insert(QStringLiteral("enabled"), obj.value(QStringLiteral("enabled")).toBool());
            row.insert(QStringLiteral("walletNotificationEnabled"), obj.value(QStringLiteral("walletNotificationEnabled")).toBool());
            row.insert(QStringLiteral("posEnabled"), obj.value(QStringLiteral("posEnabled")).toBool());
            row.insert(QStringLiteral("atmEnabled"), obj.value(QStringLiteral("atmEnabled")).toBool());
            row.insert(QStringLiteral("onlineEnabled"), obj.value(QStringLiteral("onlineEnabled")).toBool());
            row.insert(QStringLiteral("mobileWalletEnabled"), obj.value(QStringLiteral("mobileWalletEnabled")).toBool());
            row.insert(QStringLiteral("gamblingEnabled"), obj.value(QStringLiteral("gamblingEnabled")).toBool());
            row.insert(QStringLiteral("magStripeEnabled"), obj.value(QStringLiteral("magStripeEnabled")).toBool());
            row.insert(QStringLiteral("cancelled"), obj.value(QStringLiteral("cancelled")).toBool());
            row.insert(QStringLiteral("activationRequested"), obj.value(QStringLiteral("activationRequested")).toBool());
            row.insert(QStringLiteral("activated"), obj.value(QStringLiteral("activated")).toBool());
            row.insert(QStringLiteral("endOfCardNumber"), obj.value(QStringLiteral("endOfCardNumber")).toString());
            row.insert(QStringLiteral("cardAssociationUid"), obj.value(QStringLiteral("cardAssociationUid")).toString());
            row.insert(QStringLiteral("gamblingToBeEnabledAt"), obj.value(QStringLiteral("gamblingToBeEnabledAt")).toString());

            const QJsonArray currencyFlags = obj.value(QStringLiteral("currencyFlags")).toArray();
            QVariantList currencyRows;
            QStringList enabledCurrencies;
            QStringList disabledCurrencies;

            for (int j = 0; j < currencyFlags.size(); ++j) {
                const QJsonObject cf = currencyFlags.at(j).toObject();
                const QString currency = cf.value(QStringLiteral("currency")).toString();
                const bool enabled = cf.value(QStringLiteral("enabled")).toBool();

                QVariantMap cfRow;
                cfRow.insert(QStringLiteral("currency"), currency);
                cfRow.insert(QStringLiteral("enabled"), enabled);
                currencyRows.append(cfRow);

                if (enabled)
                    enabledCurrencies << currency;
                else
                    disabledCurrencies << currency;
            }

            row.insert(QStringLiteral("currencyFlags"), currencyRows);
            row.insert(QStringLiteral("enabledCurrencies"), enabledCurrencies.join(QStringLiteral(", ")));
            row.insert(QStringLiteral("disabledCurrencies"), disabledCurrencies.join(QStringLiteral(", ")));

            QString title = QStringLiteral("Card");
            const QString ending = obj.value(QStringLiteral("endOfCardNumber")).toString().trimmed();
            if (!ending.isEmpty())
                title = QStringLiteral("Card ending %1").arg(ending);

            QString subtitle;
            if (obj.value(QStringLiteral("cancelled")).toBool()) {
                subtitle = QStringLiteral("Cancelled");
            } else if (!obj.value(QStringLiteral("enabled")).toBool()) {
                subtitle = QStringLiteral("Disabled");
            } else if (obj.value(QStringLiteral("activated")).toBool()) {
                subtitle = QStringLiteral("Active");
            } else if (obj.value(QStringLiteral("activationRequested")).toBool()) {
                subtitle = QStringLiteral("Activation requested");
            } else {
                subtitle = QStringLiteral("Available");
            }

            row.insert(QStringLiteral("title"), title);
            row.insert(QStringLiteral("subtitle"), subtitle);

            rows.append(row);
        }

        std::sort(rows.begin(), rows.end(), [](const QVariant &a, const QVariant &b) {
            const QString ae = a.toMap().value(QStringLiteral("endOfCardNumber")).toString();
            const QString be = b.toMap().value(QStringLiteral("endOfCardNumber")).toString();
            return ae < be;
        });

        m_cards = rows;
        emit cardsChanged();
        setStatus(QStringLiteral("Loaded %1 card(s).").arg(rows.size()));

        setInitializing(false);
        if (!m_accountUid.isEmpty()) {
            getJson("/api/v2/account-holder/name", [this](const QByteArray &nameBody) {
                const QJsonDocument nameDoc = QJsonDocument::fromJson(nameBody);
                const QJsonObject nameRoot = nameDoc.object();
                m_accountHolderName = nameRoot.value("accountHolderName").toString();

                if (m_accountHolderName.isEmpty())
                    m_accountHolderName = m_accountName;

                emit accountChanged();
            });

            getJson("/api/v2/account-holder/individual", [this](const QByteArray &indBody) {
                const QJsonDocument indDoc = QJsonDocument::fromJson(indBody);
                const QJsonObject indRoot = indDoc.object();

                if (m_accountHolderName.isEmpty()) {
                    const QString firstName = indRoot.value("firstName").toString();
                    const QString lastName = indRoot.value("lastName").toString();
                    const QString fullName = (firstName + " " + lastName).trimmed();
                    if (!fullName.isEmpty())
                        m_accountHolderName = fullName;
                }

                m_email = indRoot.value("email").toString();
                m_phone = indRoot.value("phone").toString();

                emit accountChanged();
            });

            getJson("/api/v2/addresses", [this](const QByteArray &addrBody) {
                const QJsonDocument addrDoc = QJsonDocument::fromJson(addrBody);
                const QJsonObject addrRoot = addrDoc.object();
                const QJsonObject current = addrRoot.value("current").toObject();

                const QString line1 = current.value("line1").toString();
                const QString line2 = current.value("line2").toString();
                const QString line3 = current.value("line3").toString();
                const QString postTown = current.value("postTown").toString();
                const QString postCode = current.value("postCode").toString();
                const QString cc = current.value("countryCode").toString();

                m_countryCode = cc;
                m_postalAddress = buildPostalAddress(line1, line2, line3, postTown, postCode, cc);

                m_currentAddress.clear();
                m_currentAddress.insert(QStringLiteral("line1"), line1);
                m_currentAddress.insert(QStringLiteral("line2"), line2);
                m_currentAddress.insert(QStringLiteral("line3"), line3);
                m_currentAddress.insert(QStringLiteral("postTown"), postTown);
                m_currentAddress.insert(QStringLiteral("postCode"), postCode);
                m_currentAddress.insert(QStringLiteral("countryCode"), cc);
                m_currentAddress.insert(QStringLiteral("from"), current.value(QStringLiteral("from")).toString());
                m_currentAddress.insert(QStringLiteral("udprn"), current.value(QStringLiteral("udprn")).toString());
                m_currentAddress.insert(QStringLiteral("umprn"), current.value(QStringLiteral("umprn")).toString());

                emit accountChanged();
            });

            const QString identifiersPath =
                    QString("/api/v2/accounts/%1/identifiers").arg(m_accountUid);

            getJson(identifiersPath, [this](const QByteArray &idBody) {
                const QJsonDocument idDoc = QJsonDocument::fromJson(idBody);
                const QJsonObject idRoot = idDoc.object();

                QString accountNumber = idRoot.value("accountIdentifier").toString();
                QString sortCode = idRoot.value("bankIdentifier").toString();

                const QJsonArray ids = idRoot.value("accountIdentifiers").toArray();
                for (int i = 0; i < ids.size(); ++i) {
                    const QJsonObject obj = ids.at(i).toObject();
                    const QString type = obj.value("identifierType").toString();
                    const QString bankId = obj.value("bankIdentifier").toString();
                    const QString acctId = obj.value("accountIdentifier").toString();

                    if (type == "SORT_CODE") {
                        if (!bankId.isEmpty())
                            sortCode = bankId;
                        if (!acctId.isEmpty())
                            accountNumber = acctId;
                    }
                }

                m_accountNumber = accountNumber;
                m_sortCode = formatSortCode(sortCode);

                emit accountChanged();
            });
        }
        setStatus(QStringLiteral("Ready."));
        startRelockTimer();
    });
}

void StarlingClient::refreshPayees()
{
    const QString path = QStringLiteral("/api/v2/payees");

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();
        const QJsonArray payeesArray = root.value("payees").toArray();

        QVariantList rows;
        rows.reserve(payeesArray.size());

        for (int i = 0; i < payeesArray.size(); ++i) {
            const QJsonObject payeeObj = payeesArray.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("payeeUid"), payeeObj.value("payeeUid").toString());
            QString payeeName = payeeObj.value(QStringLiteral("payeeName")).toString().trimmed();

            if (payeeName.isEmpty()) {
                payeeName = payeeObj.value(QStringLiteral("businessName")).toString().trimmed();
            }

            if (payeeName.isEmpty()) {
                const QString firstName = payeeObj.value(QStringLiteral("firstName")).toString().trimmed();
                const QString middleName = payeeObj.value(QStringLiteral("middleName")).toString().trimmed();
                const QString lastName = payeeObj.value(QStringLiteral("lastName")).toString().trimmed();

                QStringList parts;
                if (!firstName.isEmpty())
                    parts.append(firstName);
                if (!middleName.isEmpty())
                    parts.append(middleName);
                if (!lastName.isEmpty())
                    parts.append(lastName);

                payeeName = parts.join(QStringLiteral(" "));
            }

            if (payeeName.isEmpty()) {
                payeeName = QStringLiteral("Unnamed payee");
            }

            row.insert(QStringLiteral("name"), payeeName);

            const QJsonArray accounts = payeeObj.value("accounts").toArray();

            QVariantList accountRows;
            QString subtitle;
            QString firstAccountIdentifier;
            QString firstBankIdentifier;

            for (int j = 0; j < accounts.size(); ++j) {
                const QJsonObject accObj = accounts.at(j).toObject();

                const QString accountIdentifier = accObj.value("accountIdentifier").toString();
                const QString bankIdentifier = accObj.value("bankIdentifier").toString();
                const QString bic = accObj.value("bic").toString();

                QVariantMap accountRow;
                accountRow.insert(QStringLiteral("accountIdentifier"), accountIdentifier);
                accountRow.insert(QStringLiteral("bankIdentifier"), formatSortCode(bankIdentifier));
                accountRow.insert(QStringLiteral("bic"), bic);
                accountRows.append(accountRow);

                if (j == 0) {
                    firstAccountIdentifier = accountIdentifier;
                    firstBankIdentifier = formatSortCode(bankIdentifier);
                }
            }

            if (!firstAccountIdentifier.isEmpty() && !firstBankIdentifier.isEmpty()) {
                subtitle = QStringLiteral("%1  •  %2")
                               .arg(firstAccountIdentifier, firstBankIdentifier);
            } else if (!firstAccountIdentifier.isEmpty()) {
                subtitle = firstAccountIdentifier;
            } else if (!firstBankIdentifier.isEmpty()) {
                subtitle = firstBankIdentifier;
            } else {
                subtitle = QStringLiteral("No account details");
            }

            row.insert(QStringLiteral("subtitle"), subtitle);
            row.insert(QStringLiteral("accounts"), accountRows);
            row.insert(QStringLiteral("accountCount"), accounts.size());

            rows.append(row);
        }

        std::sort(rows.begin(), rows.end(), [](const QVariant &a, const QVariant &b) {
            const QString an = a.toMap().value(QStringLiteral("name")).toString().toLower();
            const QString bn = b.toMap().value(QStringLiteral("name")).toString().toLower();
            return an < bn;
        });

        m_payees = rows;
        emit payeesChanged();
        m_lastUpdated = QDateTime::currentDateTime()
                            .toString(Qt::DefaultLocaleShortDate);
        emit lastUpdatedChanged();

        setStatus(QStringLiteral("Loaded %1 payee(s).").arg(rows.size()));

        setStatus(QStringLiteral("Loading cards..."));
        refreshCards();
    });
}

void StarlingClient::setCardBooleanControl(const QString &path,
                                           bool enabled,
                                           const QString &successStatus)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    QJsonObject payload;
    payload.insert(QStringLiteral("enabled"), enabled);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this, successStatus](const QByteArray &) {
        setStatus(successStatus);
        refreshCards();
    });
}

void StarlingClient::setCardEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("Card enabled state updated."));
}

void StarlingClient::setCardAtmEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/atm-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("ATM control updated."));
}

void StarlingClient::setCardPosEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/pos-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("POS control updated."));
}

void StarlingClient::setCardOnlineEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/online-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("Online control updated."));
}

void StarlingClient::setCardMobileWalletEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/mobile-wallet-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("Mobile wallet control updated."));
}

void StarlingClient::setCardGamblingEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/gambling-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("Gambling control updated."));
}

void StarlingClient::setCardMagStripeEnabled(const QString &cardUid, bool enabled)
{
    const QString path = QStringLiteral("/api/v2/cards/%1/controls/mag-stripe-enabled").arg(cardUid);
    setCardBooleanControl(path, enabled, QStringLiteral("Mag-stripe control updated."));
}

void StarlingClient::setCardCurrencySwitch(const QString &cardUid,
                                           const QString &currency,
                                           bool enabled)
{
    if (m_token.isEmpty()) {
        setStatus(QStringLiteral("Main token not loaded."));
        return;
    }

    if (cardUid.trimmed().isEmpty() || currency.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Missing card UID or currency."));
        return;
    }

    const QString path = QStringLiteral("/api/v2/cards/%1/controls/currency-switch").arg(cardUid);

    QJsonObject payload;
    payload.insert(QStringLiteral("currency"), currency.trimmed());
    payload.insert(QStringLiteral("enabled"), enabled);

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      payload,
                      m_token,
                      [this](const QByteArray &) {
        setStatus(QStringLiteral("Currency control updated."));
        refreshCards();
    });
}

void StarlingClient::getJson(const QString &path,
                             const std::function<void(const QByteArray &)> &onSuccess)
{
    if (!m_online) {
        setStatus(QStringLiteral("No internet connection."));
        return;
    }

    if (m_token.isEmpty()) {
        setStatus("Missing token.");
        return;
    }

    beginRequest();

    QNetworkRequest req(QUrl(QString::fromLatin1(BASE_URL) + path));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
        const int statusCode =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (reply->error() != QNetworkReply::NoError) {
            setStatus(QString("Network/API error: %1 (HTTP %2)")
                          .arg(reply->errorString())
                          .arg(statusCode));
            endRequest();
            reply->deleteLater();
            return;
        }

        const QByteArray body = reply->readAll();
        onSuccess(body);
        endRequest();
        reply->deleteLater();
    });
}

QString StarlingClient::formatMinorUnits(qint64 minorUnits, const QString &currencyCode) const
{
    const double major = static_cast<double>(minorUnits) / 100.0;
    return QString("%1 %2").arg(currencyCode, QString::number(major, 'f', 2));
}

QString StarlingClient::formatIsoDateTime(const QString &isoString) const
{
    const QDateTime dt = QDateTime::fromString(isoString, Qt::ISODate);
    if (!dt.isValid())
        return isoString;

    return dt.toLocalTime().toString("dd MMM yyyy hh:mm");
}

QString StarlingClient::formatSortCode(const QString &sortCode) const
{
    QString digits;
    for (int i = 0; i < sortCode.length(); ++i) {
        if (sortCode.at(i).isDigit())
            digits.append(sortCode.at(i));
    }

    if (digits.length() != 6)
        return sortCode;

    return QString("%1-%2-%3")
            .arg(digits.mid(0, 2))
            .arg(digits.mid(2, 2))
            .arg(digits.mid(4, 2));
}

QString StarlingClient::signedAmountString(const QString &direction,
                                           qint64 minorUnits,
                                           const QString &currencyCode) const
{
    const double major = static_cast<double>(minorUnits) / 100.0;
    const QString sign = (direction == "OUT") ? "-" : "+";
    return QString("%1%2 %3")
            .arg(sign)
            .arg(QString::number(major, 'f', 2))
            .arg(currencyCode);
}

QString StarlingClient::sectionTitleForIsoDate(const QString &isoString) const
{
    const QDateTime dt = QDateTime::fromString(isoString, Qt::ISODate);
    if (!dt.isValid())
        return QString();

    const QDate txDate = dt.toLocalTime().date();
    const QDate today = QDate::currentDate();
    const QDate yesterday = today.addDays(-1);

    if (txDate == today)
        return QStringLiteral("Today");

    if (txDate == yesterday)
        return QStringLiteral("Yesterday");

    return txDate.toString("dd MMM yyyy");
}

QString StarlingClient::buildPostalAddress(const QString &line1,
                                           const QString &line2,
                                           const QString &line3,
                                           const QString &postTown,
                                           const QString &postCode,
                                           const QString &countryCode) const
{
    QStringList parts;
    if (!line1.isEmpty()) parts << line1;
    if (!line2.isEmpty()) parts << line2;
    if (!line3.isEmpty()) parts << line3;
    if (!postTown.isEmpty()) parts << postTown;
    if (!postCode.isEmpty()) parts << postCode;
    if (!countryCode.isEmpty()) parts << countryCode;
    return parts.join("\n");
}

void StarlingClient::discoverAccount()
{
    getJson("/api/v2/accounts", [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();
        const QJsonArray accounts = root.value("accounts").toArray();

        if (accounts.isEmpty()) {
            setStatus("No account returned by API.");
            return;
        }

        QVariantList rows;
        for (int i = 0; i < accounts.size(); ++i) {
            const QJsonObject accObj = accounts.at(i).toObject();

            QVariantMap row;
            row.insert(QStringLiteral("accountUid"),
                       accObj.value(QStringLiteral("accountUid")).toString());
            row.insert(QStringLiteral("categoryUid"),
                       accObj.value(QStringLiteral("defaultCategory")).toString());
            row.insert(QStringLiteral("accountName"),
                       accObj.value(QStringLiteral("name")).toString());
            row.insert(QStringLiteral("accountType"),
                       accObj.value(QStringLiteral("accountType")).toString());
            row.insert(QStringLiteral("accountNumber"), QString());
            row.insert(QStringLiteral("sortCode"), QString());
            row.insert(QStringLiteral("isDefault"), i == 0);

            rows.append(row);
        }

        if (rows.isEmpty()) {
            setStatus("No account returned by API.");
            return;
        }

        m_sourceAccounts = rows;
        emit sourceAccountsChanged();

        const QVariantMap first = rows.first().toMap();
        m_accountUid = first.value(QStringLiteral("accountUid")).toString();
        m_categoryUid = first.value(QStringLiteral("categoryUid")).toString();
        m_accountName = first.value(QStringLiteral("accountName")).toString();
        m_accountType = first.value(QStringLiteral("accountType")).toString();

        emit accountChanged();
        setStatus("Account discovered.");

        refreshBalance();

        for (const QVariant &rowVar : m_sourceAccounts) {
            const QString uid = rowVar.toMap().value(QStringLiteral("accountUid")).toString();
            refreshSourceAccountIdentifiers(uid);
        }
    });
}

void StarlingClient::refreshBalance()
{
    if (m_accountUid.isEmpty()) {
        if (!m_initializing)
            initialize(m_startupDaysBack);
        return;
    }

    const QString path = QString("/api/v2/accounts/%1/balance").arg(m_accountUid);
    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();

        const QJsonObject cleared = root.value("clearedBalance").toObject();
        const QJsonObject effective = root.value("effectiveBalance").toObject();

        m_currency = effective.value("currency").toString("GBP");

        const qint64 clearedMinor = cleared.value("minorUnits").toVariant().toLongLong();
        const qint64 effectiveMinor = effective.value("minorUnits").toVariant().toLongLong();

        m_availableBalanceMinorUnits = effectiveMinor;

        m_clearedBalance = formatMinorUnits(clearedMinor, m_currency);
        m_availableBalance = formatMinorUnits(effectiveMinor, m_currency);

        emit balanceChanged();
        touchLastUpdated();
        setStatus("Balance updated.");
        refreshTransactions(m_startupDaysBack);
    });
}

void StarlingClient::updateTransactionNote(const QString &feedItemUid, const QString &note)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    QJsonObject body;
    body.insert(QStringLiteral("userNote"), note.trimmed());

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/user-note")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Saving transaction note..."));

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this, trimmedUid, note](const QByteArray &) {
        for (int i = 0; i < m_transactionRows.size(); ++i) {
            QVariantMap row = m_transactionRows.at(i).toMap();

            if (row.value(QStringLiteral("rowType")).toString() != QStringLiteral("transaction"))
                continue;

            if (row.value(QStringLiteral("feedItemUid")).toString() != trimmedUid)
                continue;

            row.insert(QStringLiteral("userNote"), note.trimmed());
            m_transactionRows[i] = row;
            break;
        }

        emit transactionsChanged();
        emit transactionNoteUpdated(trimmedUid, note.trimmed());

        touchLastUpdated();
        setStatus(QStringLiteral("Transaction note saved."));
    });
}

void StarlingClient::updateTransactionCategory(const QString &feedItemUid, const QString &category)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        setStatus(QStringLiteral("Account details are missing."));
        return;
    }

    const QString trimmedUid = feedItemUid.trimmed();
    const QString trimmedCategory = category.trimmed();

    if (trimmedUid.isEmpty()) {
        setStatus(QStringLiteral("Transaction UID is missing."));
        return;
    }

    if (trimmedCategory.isEmpty()) {
        setStatus(QStringLiteral("Spending category is missing."));
        return;
    }

    QJsonObject body;
    body.insert(QStringLiteral("spendingCategory"), trimmedCategory);

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/%3/spending-category")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(trimmedUid);

    setStatus(QStringLiteral("Saving transaction category..."));

    sendJsonWithToken(path,
                      QStringLiteral("PUT"),
                      body,
                      m_token,
                      [this, trimmedUid, trimmedCategory](const QByteArray &) {
        for (int i = 0; i < m_transactionRows.size(); ++i) {
            QVariantMap row = m_transactionRows.at(i).toMap();

            if (row.value(QStringLiteral("rowType")).toString() != QStringLiteral("transaction"))
                continue;

            if (row.value(QStringLiteral("feedItemUid")).toString() != trimmedUid)
                continue;

            row.insert(QStringLiteral("category"), trimmedCategory);
            m_transactionRows[i] = row;
            break;
        }

        emit transactionsChanged();
        emit transactionCategoryUpdated(trimmedUid, trimmedCategory);

        touchLastUpdated();
        setStatus(QStringLiteral("Transaction category saved."));
    });
}

void StarlingClient::refreshTransactions(int daysBack)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        if (!m_initializing)
            initialize(daysBack);
        return;
    }

    const QDateTime since = QDateTime::currentDateTimeUtc().addDays(-daysBack);
    const QString sinceIso = since.toString(Qt::ISODate);

    QUrlQuery query;
    query.addQueryItem("changesSince", sinceIso);

    const QString path = QString("/api/v2/feed/account/%1/category/%2?%3")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(query.toString(QUrl::FullyEncoded));

    if (m_initializing)
        setStatus(QStringLiteral("Loading transactions..."));

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();
        const QJsonArray items = root.value("feedItems").toArray();

        QVariantList newRows;
        QString currentSection;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QString direction = item.value("direction").toString();
            const QString counterParty = item.value("counterPartyName").toString();
            const QString reference = item.value("reference").toString();
            const QString spendingCategory = item.value("spendingCategory").toString();
            const QString updatedAt = item.value("updatedAt").toString();
            const QString status = item.value("status").toString();

            const QJsonObject amount = item.value("amount").toObject();
            const QString curr = amount.value("currency").toString("GBP");
            const qint64 minor = amount.value("minorUnits").toVariant().toLongLong();

            QString title = counterParty;
            if (title.isEmpty())
                title = reference;
            if (title.isEmpty())
                title = QStringLiteral("(no description)");

            const QString section = sectionTitleForIsoDate(updatedAt);

            if (section != currentSection) {
                QVariantMap headerRow;
                headerRow.insert("rowType", "header");
                headerRow.insert("title", section);
                newRows.append(headerRow);
                currentSection = section;
            }

            QVariantMap tx;
            tx.insert("rowType", "transaction");
            tx.insert("title", title);
            tx.insert("reference", reference);
            tx.insert("direction", direction);
            tx.insert("amount", signedAmountString(direction, minor, curr));
            tx.insert("amountValue", static_cast<qlonglong>(minor));
            tx.insert("currency", curr);
            tx.insert("date", formatIsoDateTime(updatedAt));
            tx.insert("dateRaw", updatedAt);
            tx.insert("section", section);
            tx.insert("status", status);
            tx.insert("category", spendingCategory);
            tx.insert("feedItemUid", item.value("feedItemUid").toString());
            tx.insert("userNote", item.value("userNote").toString());

            newRows.append(tx);
        }

        m_transactionRows = newRows;
        emit transactionsChanged();
        touchLastUpdated();
        setStatus(QString("Loaded %1 transaction(s).").arg(items.size()));

        setStatus(QStringLiteral("Loading payees..."));
        refreshPayees();
    });
}

void StarlingClient::refreshTransactionsRange(const QString &fromDate, const QString &toDate)
{
    if (m_accountUid.isEmpty() || m_categoryUid.isEmpty()) {
        if (!m_initializing)
            initialize(m_startupDaysBack > 0 ? m_startupDaysBack : 14);
        return;
    }

    const QDate from = QDate::fromString(fromDate.trimmed(), Qt::ISODate);
    const QDate to = QDate::fromString(toDate.trimmed(), Qt::ISODate);

    if (!from.isValid() || !to.isValid()) {
        setStatus(QStringLiteral("Invalid transaction date range."));
        return;
    }

    if (from > to) {
        setStatus(QStringLiteral("From date must be before To date."));
        return;
    }

    const QDateTime minDateTime(from, QTime(0, 0, 0), Qt::UTC);
    const QDateTime maxDateTime(to.addDays(1), QTime(0, 0, 0), Qt::UTC);

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("minTransactionTimestamp"),
                       minDateTime.toString(Qt::ISODate));
    query.addQueryItem(QStringLiteral("maxTransactionTimestamp"),
                       maxDateTime.toString(Qt::ISODate));

    const QString path =
            QStringLiteral("/api/v2/feed/account/%1/category/%2/transactions-between?%3")
            .arg(m_accountUid)
            .arg(m_categoryUid)
            .arg(query.toString(QUrl::FullyEncoded));

    setStatus(QStringLiteral("Loading transactions..."));

    getJson(path, [this](const QByteArray &body) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        const QJsonObject root = doc.object();
        const QJsonArray items = root.value(QStringLiteral("feedItems")).toArray();

        QVariantList newRows;
        QString currentSection;

        for (int i = 0; i < items.size(); ++i) {
            const QJsonObject item = items.at(i).toObject();

            const QString direction = item.value(QStringLiteral("direction")).toString();
            const QString counterParty = item.value(QStringLiteral("counterPartyName")).toString();
            const QString reference = item.value(QStringLiteral("reference")).toString();
            const QString spendingCategory = item.value(QStringLiteral("spendingCategory")).toString();
            const QString updatedAt = item.value(QStringLiteral("updatedAt")).toString();
            const QString transactionTime = item.value(QStringLiteral("transactionTime")).toString();
            const QString status = item.value(QStringLiteral("status")).toString();

            const QString dateForDisplay =
                    !transactionTime.isEmpty() ? transactionTime : updatedAt;

            const QJsonObject amount = item.value(QStringLiteral("amount")).toObject();
            const QString curr = amount.value(QStringLiteral("currency")).toString(QStringLiteral("GBP"));
            const qint64 minor = amount.value(QStringLiteral("minorUnits")).toVariant().toLongLong();

            QString title = counterParty;
            if (title.isEmpty())
                title = reference;
            if (title.isEmpty())
                title = QStringLiteral("(no description)");

            const QString section = sectionTitleForIsoDate(dateForDisplay);

            if (section != currentSection) {
                QVariantMap headerRow;
                headerRow.insert(QStringLiteral("rowType"), QStringLiteral("header"));
                headerRow.insert(QStringLiteral("title"), section);
                newRows.append(headerRow);
                currentSection = section;
            }

            QVariantMap tx;
            tx.insert(QStringLiteral("rowType"), QStringLiteral("transaction"));
            tx.insert(QStringLiteral("title"), title);
            tx.insert(QStringLiteral("reference"), reference);
            tx.insert(QStringLiteral("direction"), direction);
            tx.insert(QStringLiteral("amount"), signedAmountString(direction, minor, curr));
            tx.insert(QStringLiteral("amountValue"), static_cast<qint64>(minor));
            tx.insert(QStringLiteral("currency"), curr);
            tx.insert(QStringLiteral("date"), formatIsoDateTime(dateForDisplay));
            tx.insert(QStringLiteral("dateRaw"), dateForDisplay);
            tx.insert(QStringLiteral("section"), section);
            tx.insert(QStringLiteral("status"), status);
            tx.insert(QStringLiteral("category"), spendingCategory);
            tx.insert(QStringLiteral("feedItemUid"), item.value(QStringLiteral("feedItemUid")).toString());
            tx.insert(QStringLiteral("userNote"), item.value(QStringLiteral("userNote")).toString());

            newRows.append(tx);
        }

        m_transactionRows = newRows;
        emit transactionsChanged();

        touchLastUpdated();
        setStatus(QStringLiteral("Loaded %1 transaction(s).").arg(items.size()));
    });
}

bool StarlingClient::factoryResetAfterConfirmation()
{
    QStringList failures;

    auto clearIfPresent = [&](bool present, const QString &name, const std::function<bool()> &fn) {
        if (!present)
            return;
        if (!fn())
            failures << name;
    };

    // Stored secrets
    clearIfPresent(!m_tokenStore.loadToken().trimmed().isEmpty(),
                   QStringLiteral("PAT"),
                   [this]() { return m_tokenStore.clearToken(); });

    clearIfPresent(!m_tokenStore.loadPayeeWriteToken().trimmed().isEmpty(),
                   QStringLiteral("payee-write PAT"),
                   [this]() { return m_tokenStore.clearPayeeWriteToken(); });

    clearIfPresent(!m_tokenStore.loadApiKeyId().trimmed().isEmpty(),
                   QStringLiteral("API key ID"),
                   [this]() { return m_tokenStore.clearApiKeyId(); });

    clearIfPresent(!m_tokenStore.loadPrivateApiKeyPem().trimmed().isEmpty(),
                   QStringLiteral("private API key"),
                   [this]() { return m_tokenStore.clearPrivateApiKeyPem(); });

    clearIfPresent(hasStoredPhysicalCard(),
                   QStringLiteral("physical card"),
                   [this]() { return m_tokenStore.clearPhysicalCard(); });

    clearIfPresent(hasStoredPhysicalCardCvv(),
                   QStringLiteral("card CVV"),
                   [this]() { return m_tokenStore.clearPhysicalCardCvv(); });

    clearIfPresent(hasStoredPhysicalCardPin(),
                   QStringLiteral("card PIN"),
                   [this]() { return m_tokenStore.clearPhysicalCardPin(); });

    // In-memory state
    setToken(QString());
    setPayeeWriteToken(QString());
    setApiKeyId(QString());
    setPrivateApiKeyPem(QString());

    resetLoadedData();
    clearTransactions();
    clearPayees();
    clearPayeeDetail();
    clearCards();
    clearConsentState();
    clearPaymentDraft();
    clearPaymentResult();

    // Clear app PIN from QSettings
    m_pinHash.clear();
    m_pinSalt.clear();
    {
        QSettings settings;
        settings.remove(QStringLiteral("security/pinHash"));
        settings.remove(QStringLiteral("security/pinSalt"));
    }
    emit pinEnabledChanged();
    emit pinSetupRequiredChanged();

    // Clear PIN/UI state
    setPinError(QString());
    setPinPromptVisible(false);
    clearPinConfirmation();
    clearPinSettingsError();

    // Leave settings flow cleanly
    clearNavigationTarget();
    setNavigationTarget(QStringLiteral("Main"));

    if (!failures.isEmpty()) {
        setStatus(QStringLiteral("Factory reset completed with errors clearing: %1")
                  .arg(failures.join(QStringLiteral(", "))));
        return false;
    }

    setStatus(QStringLiteral("All locally stored data deleted."));
    return true;
}