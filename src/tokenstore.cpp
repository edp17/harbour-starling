#include "tokenstore.h"

#include <QByteArray>
#include <QSettings>
#include <QString>

#include <Secrets/secret.h>
#include <Secrets/secretmanager.h>
#include <Secrets/storesecretrequest.h>
#include <Secrets/storedsecretrequest.h>
#include <Secrets/deletesecretrequest.h>
#include <Secrets/result.h>

namespace {

static const char *SECRET_MAIN_PAT = "starling-pat";
static const char *SECRET_PAYEE_WRITE_PAT_LEGACY = "starling-payee-write-pat";
static const char *SECRET_PAYEE_WRITE_PAT = "starling-payee-write-pat-v2";
static const char *SECRET_API_KEY_ID = "starling-api-key-id";
static const char *SECRET_PRIVATE_API_KEY_PEM = "starling-private-api-key-pem";

static const char *SETTINGS_ORG = "harbour-starling";
static const char *SETTINGS_APP = "harbour-starling";
static const char *SETTINGS_GROUP = "auth";
static const char *SETTINGS_KEY_HAS_MAIN_TOKEN = "hasStoredToken";
static const char *SETTINGS_KEY_HAS_PAYEE_WRITE_TOKEN = "hasStoredPayeeWriteToken";
static const char *SETTINGS_KEY_HAS_API_KEY_ID = "hasStoredApiKeyId";
static const char *SETTINGS_KEY_HAS_PRIVATE_API_KEY_PEM = "hasStoredPrivateApiKeyPem";
static const QString SECRET_PHYSICAL_CARD = QStringLiteral("physical_card_local");
static const QString SECRET_PHYSICAL_CARD_PIN = QStringLiteral("physical_card_pin");
static const QString SECRET_PHYSICAL_CARD_CVV = QStringLiteral("physical_card_cvv");

static Sailfish::Secrets::Secret::Identifier tokenIdentifier(const QString &secretName)
{
    return Sailfish::Secrets::Secret::Identifier(
                secretName,
                QString(),
                Sailfish::Secrets::SecretManager::DefaultStoragePluginName);
}

static bool isOwnedByDifferentApplicationError(const QString &error)
{
    return error.contains(QStringLiteral("owned by a different application"),
                          Qt::CaseInsensitive);
}

static bool isIgnorableClearError(const QString &error)
{
    if (error.isEmpty())
        return true;

    return error.contains(QStringLiteral("not found"), Qt::CaseInsensitive)
            || error.contains(QStringLiteral("does not exist"), Qt::CaseInsensitive)
            || isOwnedByDifferentApplicationError(error);
}

} // namespace

TokenStore::TokenStore()
{
}

QString TokenStore::loadSecret(const QString &secretName) const
{
    m_lastError.clear();

    Sailfish::Secrets::SecretManager manager;
    Sailfish::Secrets::StoredSecretRequest request;

    request.setManager(&manager);
    request.setIdentifier(tokenIdentifier(secretName));
    request.setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();

    if (request.result().code() == Sailfish::Secrets::Result::Succeeded) {
        return QString::fromUtf8(request.secret().data()).trimmed();
    }

    m_lastError = request.result().errorMessage();
    return QString();
}

bool TokenStore::saveSecret(const QString &secretName, const QString &token)
{
    m_lastError.clear();

    const QString cleaned = token.trimmed();
    if (cleaned.isEmpty()) {
        setError(QStringLiteral("Token is empty"));
        return false;
    }

    // Standalone secrets cannot always be overwritten directly,
    // so delete the old one first if it exists.
    {
        Sailfish::Secrets::SecretManager manager;
        Sailfish::Secrets::DeleteSecretRequest deleteRequest;

        deleteRequest.setManager(&manager);
        deleteRequest.setIdentifier(tokenIdentifier(secretName));
        deleteRequest.setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
        deleteRequest.startRequest();
        deleteRequest.waitForFinished();

        // Ignore delete failure here, because the secret may simply not exist yet.
    }

    Sailfish::Secrets::Secret secret(tokenIdentifier(secretName));
    secret.setData(cleaned.toUtf8());
    secret.setType(Sailfish::Secrets::Secret::TypeBlob);

    Sailfish::Secrets::SecretManager manager;
    Sailfish::Secrets::StoreSecretRequest request;

    request.setManager(&manager);
    request.setSecretStorageType(Sailfish::Secrets::StoreSecretRequest::StandaloneDeviceLockSecret);
    request.setDeviceLockUnlockSemantic(
                Sailfish::Secrets::SecretManager::DeviceLockKeepUnlocked);
    request.setAccessControlMode(
                Sailfish::Secrets::SecretManager::OwnerOnlyMode);
    request.setEncryptionPluginName(
                Sailfish::Secrets::SecretManager::DefaultEncryptionPluginName);
    request.setUserInteractionMode(
                Sailfish::Secrets::SecretManager::SystemInteraction);
    request.setSecret(secret);

    request.startRequest();
    request.waitForFinished();

    if (request.result().code() != Sailfish::Secrets::Result::Succeeded) {
        setError(request.result().errorMessage());
        return false;
    }

    return true;
}

bool TokenStore::clearSecret(const QString &secretName)
{
    m_lastError.clear();

    Sailfish::Secrets::SecretManager manager;
    Sailfish::Secrets::DeleteSecretRequest request;

    request.setManager(&manager);
    request.setIdentifier(tokenIdentifier(secretName));
    request.setUserInteractionMode(Sailfish::Secrets::SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();

    if (request.result().code() == Sailfish::Secrets::Result::Succeeded) {
        return true;
    }

    const QString error = request.result().errorMessage();
    if (isIgnorableClearError(error)) {
        m_lastError.clear();
        return true;
    }

    setError(error);
    return false;
}

bool TokenStore::readFlag(const QString &key) const
{
    QSettings settings(QString::fromLatin1(SETTINGS_ORG),
                       QString::fromLatin1(SETTINGS_APP));
    settings.beginGroup(QString::fromLatin1(SETTINGS_GROUP));
    const bool value = settings.value(key, false).toBool();
    settings.endGroup();
    return value;
}

void TokenStore::writeFlag(const QString &key, bool value)
{
    QSettings settings(QString::fromLatin1(SETTINGS_ORG),
                       QString::fromLatin1(SETTINGS_APP));
    settings.beginGroup(QString::fromLatin1(SETTINGS_GROUP));
    settings.setValue(key, value);
    settings.endGroup();
    settings.sync();
}

QString TokenStore::loadToken() const
{
    return loadSecret(QString::fromLatin1(SECRET_MAIN_PAT));
}

bool TokenStore::saveToken(const QString &token)
{
    if (!saveSecret(QString::fromLatin1(SECRET_MAIN_PAT), token))
        return false;

    setStoredTokenFlag(true);
    return true;
}

bool TokenStore::clearToken()
{
    if (!clearSecret(QString::fromLatin1(SECRET_MAIN_PAT)))
        return false;

    setStoredTokenFlag(false);
    return true;
}

QString TokenStore::loadPayeeWriteToken() const
{
    return loadSecret(QString::fromLatin1(SECRET_PAYEE_WRITE_PAT));
}

bool TokenStore::savePayeeWriteToken(const QString &token)
{
    if (!saveSecret(QString::fromLatin1(SECRET_PAYEE_WRITE_PAT), token))
        return false;

    // Best-effort cleanup of the legacy secret. Ignore ownership errors.
    clearSecret(QString::fromLatin1(SECRET_PAYEE_WRITE_PAT_LEGACY));
    if (isOwnedByDifferentApplicationError(m_lastError))
        m_lastError.clear();

    setStoredPayeeWriteTokenFlag(true);
    return true;
}

bool TokenStore::clearPayeeWriteToken()
{
    const bool clearedCurrent = clearSecret(QString::fromLatin1(SECRET_PAYEE_WRITE_PAT));
    const bool clearedLegacy = clearSecret(QString::fromLatin1(SECRET_PAYEE_WRITE_PAT_LEGACY));

    if (!clearedCurrent || !clearedLegacy)
        return false;

    setStoredPayeeWriteTokenFlag(false);
    m_lastError.clear();
    return true;
}

QString TokenStore::loadApiKeyId() const
{
    return loadSecret(QString::fromLatin1(SECRET_API_KEY_ID));
}

bool TokenStore::saveApiKeyId(const QString &value)
{
    if (!saveSecret(QString::fromLatin1(SECRET_API_KEY_ID), value))
        return false;

    setStoredApiKeyIdFlag(true);
    return true;
}

bool TokenStore::clearApiKeyId()
{
    if (!clearSecret(QString::fromLatin1(SECRET_API_KEY_ID)))
        return false;

    setStoredApiKeyIdFlag(false);
    return true;
}

QString TokenStore::loadPrivateApiKeyPem() const
{
    return loadSecret(QString::fromLatin1(SECRET_PRIVATE_API_KEY_PEM));
}

bool TokenStore::savePrivateApiKeyPem(const QString &value)
{
    if (!saveSecret(QString::fromLatin1(SECRET_PRIVATE_API_KEY_PEM), value))
        return false;

    setStoredPrivateApiKeyPemFlag(true);
    return true;
}

bool TokenStore::clearPrivateApiKeyPem()
{
    if (!clearSecret(QString::fromLatin1(SECRET_PRIVATE_API_KEY_PEM)))
        return false;

    setStoredPrivateApiKeyPemFlag(false);
    return true;
}

bool TokenStore::hasStoredTokenFlag() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_MAIN_TOKEN));
}

void TokenStore::setStoredTokenFlag(bool value)
{
    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_MAIN_TOKEN), value);
}

bool TokenStore::hasStoredPayeeWriteTokenFlag() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PAYEE_WRITE_TOKEN));
}

void TokenStore::setStoredPayeeWriteTokenFlag(bool value)
{
    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PAYEE_WRITE_TOKEN), value);
}

bool TokenStore::hasStoredApiKeyIdFlag() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_API_KEY_ID));
}

void TokenStore::setStoredApiKeyIdFlag(bool value)
{
    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_API_KEY_ID), value);
}

bool TokenStore::hasStoredPrivateApiKeyPemFlag() const
{
    return readFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PRIVATE_API_KEY_PEM));
}

void TokenStore::setStoredPrivateApiKeyPemFlag(bool value)
{
    writeFlag(QString::fromLatin1(SETTINGS_KEY_HAS_PRIVATE_API_KEY_PEM), value);
}

QString TokenStore::lastError() const
{
    return m_lastError;
}

void TokenStore::setError(const QString &error) const
{
    m_lastError = error;
}

// Card
QString TokenStore::loadPhysicalCard() const
{
    return loadSecret(SECRET_PHYSICAL_CARD);
}

bool TokenStore::savePhysicalCard(const QString &json)
{
    return saveSecret(SECRET_PHYSICAL_CARD, json);
}

bool TokenStore::clearPhysicalCard()
{
    return clearSecret(SECRET_PHYSICAL_CARD);
}

// PIN
QString TokenStore::loadPhysicalCardPin() const
{
    return loadSecret(SECRET_PHYSICAL_CARD_PIN);
}

bool TokenStore::savePhysicalCardPin(const QString &pin)
{
    return saveSecret(SECRET_PHYSICAL_CARD_PIN, pin);
}

bool TokenStore::clearPhysicalCardPin()
{
    return clearSecret(SECRET_PHYSICAL_CARD_PIN);
}

// CVV
QString TokenStore::loadPhysicalCardCvv() const
{
    return loadSecret(SECRET_PHYSICAL_CARD_CVV);
}

bool TokenStore::savePhysicalCardCvv(const QString &cvv)
{
    return saveSecret(SECRET_PHYSICAL_CARD_CVV, cvv);
}

bool TokenStore::clearPhysicalCardCvv()
{
    return clearSecret(SECRET_PHYSICAL_CARD_CVV);
}