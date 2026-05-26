#ifndef STARLINGCLIENT_H
#define STARLINGCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QTimer>
#include <functional>
#include <QVariantMap>
#include <QNetworkConfigurationManager>
#include "tokenstore.h"

class StarlingClient : public QObject
{
    Q_OBJECT

    // Properties
    Q_PROPERTY(QString token READ token WRITE setToken NOTIFY tokenChanged)
    Q_PROPERTY(QString accountUid READ accountUid NOTIFY accountChanged)
    Q_PROPERTY(QString categoryUid READ categoryUid NOTIFY accountChanged)
    Q_PROPERTY(QString availableBalance READ availableBalance NOTIFY balanceChanged)
    Q_PROPERTY(QString clearedBalance READ clearedBalance NOTIFY balanceChanged)
    Q_PROPERTY(QString currency READ currency NOTIFY balanceChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantList transactionRows READ transactionRows NOTIFY transactionsChanged)
    Q_PROPERTY(QVariantList recentTransactions READ recentTransactions NOTIFY transactionsChanged)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY lastUpdatedChanged)

    Q_PROPERTY(QString accountHolderName READ accountHolderName NOTIFY accountChanged)
    Q_PROPERTY(QString accountName READ accountName NOTIFY accountChanged)
    Q_PROPERTY(QString accountNumber READ accountNumber NOTIFY accountChanged)
    Q_PROPERTY(QString sortCode READ sortCode NOTIFY accountChanged)
    Q_PROPERTY(QString accountType READ accountType NOTIFY accountChanged)

    Q_PROPERTY(QString email READ email NOTIFY accountChanged)
    Q_PROPERTY(QString phone READ phone NOTIFY accountChanged)
    Q_PROPERTY(QString postalAddress READ postalAddress NOTIFY accountChanged)
    Q_PROPERTY(QString countryCode READ countryCode NOTIFY accountChanged)

    Q_PROPERTY(bool initializing READ initializing NOTIFY initializingChanged)
    Q_PROPERTY(QVariantList payees READ payees NOTIFY payeesChanged)
    Q_PROPERTY(QVariantList cards READ cards NOTIFY cardsChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    Q_PROPERTY(int autoLockMinutes READ autoLockMinutes WRITE setAutoLockMinutes NOTIFY autoLockMinutesChanged)
    Q_PROPERTY(QString navigationTarget READ navigationTarget NOTIFY navigationTargetChanged)
    Q_PROPERTY(QString payeeWriteToken READ payeeWriteToken WRITE setPayeeWriteToken NOTIFY payeeWriteTokenChanged)
    Q_PROPERTY(QString apiKeyId READ apiKeyId WRITE setApiKeyId NOTIFY apiKeyIdChanged)
    Q_PROPERTY(QString privateApiKeyPem READ privateApiKeyPem WRITE setPrivateApiKeyPem NOTIFY privateApiKeyPemChanged)
    Q_PROPERTY(QVariantMap payeeDetail READ payeeDetail NOTIFY payeeDetailChanged)
    Q_PROPERTY(bool consentPending READ consentPending NOTIFY consentPendingChanged)
    Q_PROPERTY(QString consentMessage READ consentMessage NOTIFY consentMessageChanged)
    Q_PROPERTY(bool lockOnBackground READ lockOnBackground WRITE setLockOnBackground NOTIFY lockOnBackgroundChanged)

    Q_PROPERTY(bool pinEnabled READ pinEnabled NOTIFY pinEnabledChanged)
    Q_PROPERTY(bool pinPromptVisible READ pinPromptVisible NOTIFY pinPromptVisibleChanged)
    Q_PROPERTY(QString pinError READ pinError NOTIFY pinErrorChanged)
    Q_PROPERTY(QString pinSettingsError READ pinSettingsError NOTIFY pinSettingsErrorChanged)
    Q_PROPERTY(bool pinSetupRequired READ pinSetupRequired NOTIFY pinSetupRequiredChanged)

    Q_PROPERTY(QVariantMap paymentDraft READ paymentDraft NOTIFY paymentDraftChanged)
    Q_PROPERTY(QString paymentPreviewJson READ paymentPreviewJson NOTIFY paymentPreviewJsonChanged)
    Q_PROPERTY(bool paymentPreviewReady READ paymentPreviewReady NOTIFY paymentPreviewReadyChanged)
    Q_PROPERTY(bool paymentSubmitting READ paymentSubmitting NOTIFY paymentSubmittingChanged)
    Q_PROPERTY(bool paymentSubmitted READ paymentSubmitted NOTIFY paymentSubmittedChanged)
    Q_PROPERTY(QString paymentResultMessage READ paymentResultMessage NOTIFY paymentResultMessageChanged)
    Q_PROPERTY(bool pinConfirmationPending READ pinConfirmationPending NOTIFY pinConfirmationPendingChanged)
    Q_PROPERTY(QVariantList sourceAccounts READ sourceAccounts NOTIFY sourceAccountsChanged)
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)

    Q_PROPERTY(QVariantList directDebitMandates READ directDebitMandates NOTIFY directDebitMandatesChanged)
    Q_PROPERTY(QVariantList standingOrders READ standingOrders NOTIFY standingOrdersChanged)
    Q_PROPERTY(QString lastFeedExportCsvPath READ lastFeedExportCsvPath NOTIFY lastFeedExportCsvPathChanged)
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY spacesChanged)
    Q_PROPERTY(qint64 availableBalanceMinorUnits READ availableBalanceMinorUnits NOTIFY balanceChanged)

public:
    explicit StarlingClient(QObject *parent = nullptr);

    // getters
    QString token() const;
    void setToken(const QString &token);

    QString accountUid() const;
    QString categoryUid() const;
    QString availableBalance() const;
    QString clearedBalance() const;
    QString currency() const;
    QString status() const;
    bool busy() const;
    QVariantList transactionRows() const;
    QVariantList recentTransactions() const;
    QString lastUpdated() const;

    QString accountHolderName() const;
    QString accountName() const;
    QString accountNumber() const;
    QString sortCode() const;
    QString accountType() const;

    QString email() const;
    QString phone() const;
    QString postalAddress() const;
    QString countryCode() const;
    QString navigationTarget() const;
    bool pinEnabled() const;
    bool pinPromptVisible() const;
    QString pinError() const;
    bool pinSetupRequired() const;
    QVariantMap paymentDraft() const;
    QString paymentPreviewJson() const;
    bool paymentPreviewReady() const;
    bool paymentSubmitting() const;
    bool paymentSubmitted() const;
    QString paymentResultMessage() const;
    QVariantList sourceAccounts() const;
    bool online() const;

    QVariantList directDebitMandates() const;
    QVariantList standingOrders() const;
    QString lastFeedExportCsvPath() const;

    QVariantList spaces() const;
    Q_INVOKABLE void refreshSpaces();

    qint64 availableBalanceMinorUnits() const;

    // invokables
    Q_INVOKABLE void discoverAccount();
    Q_INVOKABLE void refreshBalance();
    Q_INVOKABLE void refreshTransactions(int daysBack = 14);
    Q_INVOKABLE void refreshTransactionsRange(const QString &fromDate, const QString &toDate);
    Q_INVOKABLE void saveToken();
    Q_INVOKABLE void loadToken();
    Q_INVOKABLE void clearToken();

    bool initializing() const;
    Q_INVOKABLE void initialize(int daysBack = 14);
    QVariantList payees() const;
    Q_INVOKABLE void refreshPayees();
    QVariantList cards() const;
    Q_INVOKABLE void refreshCards();

    bool locked() const;
    Q_INVOKABLE void unlock();
    Q_INVOKABLE void lock();
    Q_INVOKABLE void refreshAll(int daysBack = 14);
    Q_INVOKABLE void requestOpenSettings();
    Q_INVOKABLE void clearNavigationTarget();

    QString payeeWriteToken() const;
    void setPayeeWriteToken(const QString &token);

    Q_INVOKABLE void savePayeeWriteToken();
    Q_INVOKABLE void loadPayeeWriteToken();
    Q_INVOKABLE void clearPayeeWriteToken();

    QString apiKeyId() const;
    void setApiKeyId(const QString &value);

    Q_INVOKABLE void saveApiKeyId();
    Q_INVOKABLE void loadApiKeyId();
    Q_INVOKABLE void clearApiKeyId();

    QString privateApiKeyPem() const;
    void setPrivateApiKeyPem(const QString &value);

    Q_INVOKABLE void savePrivateApiKeyPem();
    Q_INVOKABLE void loadPrivateApiKeyPem();
    Q_INVOKABLE void clearPrivateApiKeyPem();

    Q_INVOKABLE void createPayee(const QString &payeeName,
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
                                 const QString &secondaryIdentifier);

    Q_INVOKABLE void createPayeeAccount(const QString &payeeUid,
                                        const QString &accountDescription,
                                        bool defaultAccount,
                                        const QString &countryCode,
                                        const QString &accountIdentifier,
                                        const QString &bankIdentifier,
                                        const QString &bankIdentifierType,
                                        const QString &secondaryIdentifier);

    Q_INVOKABLE void updatePayee(const QString &payeeUid,
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
                                 const QString &secondaryIdentifier);
    Q_INVOKABLE void updatePayeeNames(const QString &payeeUid,
                                      const QString &payeeName,
                                      const QString &firstName,
                                      const QString &middleName,
                                      const QString &lastName);

    Q_INVOKABLE void deletePayee(const QString &payeeUid);
    Q_INVOKABLE void deletePayeeAccount(const QString &payeeUid, const QString &accountUid);
    QVariantMap payeeDetail() const;
    Q_INVOKABLE void refreshPayeeDetail(const QString &payeeUid);
    Q_INVOKABLE void updatePayeeAccountDescription(const QString &payeeUid,
                                                   const QString &payeeAccountUid,
                                                   const QString &description);

    Q_INVOKABLE void setCardEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardAtmEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardPosEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardOnlineEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardMobileWalletEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardGamblingEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardMagStripeEnabled(const QString &cardUid, bool enabled);
    Q_INVOKABLE void setCardCurrencySwitch(const QString &cardUid, const QString &currency, bool enabled);
    bool consentPending() const;
    QString consentMessage() const;
    Q_INVOKABLE void dismissConsentMessage();
    int autoLockMinutes() const;
    void setAutoLockMinutes(int minutes);

    Q_INVOKABLE void registerUserActivity();

    bool lockOnBackground() const;
    void setLockOnBackground(bool value);

    Q_INVOKABLE bool setAppPin(const QString &pin, const QString &confirmPin);
    Q_INVOKABLE bool changeAppPin(const QString &currentPin,
                                  const QString &newPin,
                                  const QString &confirmPin);
    Q_INVOKABLE bool submitPin(const QString &pin);
    Q_INVOKABLE void cancelPinPrompt();
    Q_INVOKABLE void clearPinError();
    QString pinSettingsError() const;
    Q_INVOKABLE void clearPinSettingsError();
    Q_INVOKABLE void preparePaymentDraft(const QString &sourceAccountUid,
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
                                         const QString &reference);

    Q_INVOKABLE bool buildPaymentPreview();
    Q_INVOKABLE void clearPaymentDraft();
    Q_INVOKABLE bool submitPreparedPayment();
    Q_INVOKABLE void clearPaymentResult();

    bool pinConfirmationPending() const;
    Q_INVOKABLE void requestPinConfirmation();
    Q_INVOKABLE void clearPinConfirmation();
    Q_INVOKABLE bool changeAppPinAfterConfirmation(const QString &newPin,
                                                   const QString &confirmPin);

    Q_INVOKABLE bool hasStoredPhysicalCard() const;

    Q_INVOKABLE bool savePhysicalCardAfterConfirmation(const QString &cardholderName,
                                                       const QString &cardNumber,
                                                       const QString &expiryMonth,
                                                       const QString &expiryYear);

    Q_INVOKABLE QVariantMap loadStoredPhysicalCardMasked() const;
    Q_INVOKABLE QVariantMap loadStoredPhysicalCardFullAfterConfirmation();

    Q_INVOKABLE bool deleteStoredPhysicalCardAfterConfirmation();

    Q_INVOKABLE bool hasStoredPhysicalCardPin() const;
    Q_INVOKABLE bool savePhysicalCardPinAfterConfirmation(const QString &pin,
                                                      const QString &confirmPin);
    Q_INVOKABLE QString loadStoredPhysicalCardPinAfterConfirmation();
    Q_INVOKABLE bool deleteStoredPhysicalCardPinAfterConfirmation();

    Q_INVOKABLE bool hasStoredPhysicalCardCvv() const;
    Q_INVOKABLE bool savePhysicalCardCvvAfterConfirmation(const QString &cvv);
    Q_INVOKABLE QString loadStoredPhysicalCardCvvAfterConfirmation();
    Q_INVOKABLE bool deleteStoredPhysicalCardCvvAfterConfirmation();
    Q_INVOKABLE bool factoryResetAfterConfirmation();

    Q_INVOKABLE void refreshDirectDebitMandates();
    Q_INVOKABLE void refreshStandingOrders();
    Q_INVOKABLE void refreshRegularPayments();
    Q_INVOKABLE void cancelDirectDebitMandate(const QString &mandateUid);
    Q_INVOKABLE void cancelStandingOrder(const QString &paymentOrderUid);
    Q_INVOKABLE void downloadFeedExportCsvRange(const QString &startDate, const QString &endDate);
    Q_INVOKABLE void createSavingsGoal(const QString &name, const QString &targetAmount);
    Q_INVOKABLE void addMoneyToSavingsGoal(const QString &savingsGoalUid, const QString &amount);
    Q_INVOKABLE void withdrawMoneyFromSavingsGoal(const QString &savingsGoalUid, const QString &amount);
    Q_INVOKABLE void deleteSavingsGoal(const QString &savingsGoalUid);

signals:
    void tokenChanged();
    void accountChanged();
    void balanceChanged();
    void statusChanged();
    void busyChanged();
    void transactionsChanged();
    void lastUpdatedChanged();
    void initializingChanged();
    void payeesChanged();
    void cardsChanged();
    void lockedChanged();
    void navigationTargetChanged();
    void payeeWriteTokenChanged();
    void apiKeyIdChanged();
    void privateApiKeyPemChanged();
    void payeeDetailChanged();
    void payeeDeleted(const QString &payeeUid);
    void consentPendingChanged();
    void consentMessageChanged();
    void autoLockMinutesChanged();
    void lockOnBackgroundChanged();
    void pinEnabledChanged();
    void pinPromptVisibleChanged();
    void pinErrorChanged();
    void pinSettingsErrorChanged();
    void pinSetupRequiredChanged();
    void paymentDraftChanged();
    void paymentPreviewJsonChanged();
    void paymentPreviewReadyChanged();
    void paymentSubmittingChanged();
    void paymentSubmittedChanged();
    void paymentResultMessageChanged();
    void pinConfirmationPendingChanged();
    void pinConfirmed();
    void sourceAccountsChanged();
    void onlineChanged();
    void directDebitMandatesChanged();
    void standingOrdersChanged();
    void lastFeedExportCsvPathChanged();
    void spacesChanged();
    void savingsGoalCreated();
    void savingsGoalTransferCompleted();
    void savingsGoalDeleted();

private:
    // helpers
    void setBusy(bool value);
    void setStatus(const QString &value);
    void clearTransactions();
    void touchLastUpdated();
    void getJson(const QString &path,
                 const std::function<void(const QByteArray &)> &onSuccess);
    void beginRequest();
    void endRequest();
    void setInitializing(bool value);
    void resetLoadedData();
    void clearPayees();
    void clearCards();
    void setLocked(bool value);
    void continuePendingAction();
    void startRelockTimer();
    void stopRelockTimer();
    void setNavigationTarget(const QString &target);
    void clearPayeeDetail();
    void setCardBooleanControl(const QString &path, bool enabled, const QString &successStatus);
    void setConsentPending(bool pending);
    void setConsentMessage(const QString &message);
    void clearConsentState();
    void setPinSettingsError(const QString &value);
    void setPaymentSubmitting(bool value);
    void setPaymentSubmitted(bool value);
    void setPaymentResultMessage(const QString &value);
    void refreshSourceAccountIdentifiers(const QString &accountUid);
    void setOnline(bool value);

    QString formatMinorUnits(qint64 minorUnits, const QString &currencyCode) const;
    QString formatIsoDateTime(const QString &isoString) const;
    QString signedAmountString(const QString &direction,
                               qint64 minorUnits,
                               const QString &currencyCode) const;
    QString sectionTitleForIsoDate(const QString &isoString) const;
    QString buildPostalAddress(const QString &line1,
                               const QString &line2,
                               const QString &line3,
                               const QString &postTown,
                               const QString &postCode,
                               const QString &countryCode) const;
    QString formatSortCode(const QString &sortCode) const;
    QVariantList m_payees;
    QVariantList m_cards;
    QTimer m_relockTimer;
    QString m_pendingAction;

    void sendJsonWithToken(const QString &path,
                           const QString &httpMethod,
                           const QJsonObject &payload,
                           const QString &bearerToken,
                           const std::function<void(const QByteArray &)> &onSuccess,
                           bool includeDigestHeader = false);

    void sendDeleteWithToken(const QString &path,
                             const QString &bearerToken,
                             const std::function<void(const QByteArray &)> &onSuccess);

    QJsonObject buildPayeeAccountObject(const QString &accountDescription,
                                        bool defaultAccount,
                                        const QString &countryCode,
                                        const QString &accountIdentifier,
                                        const QString &bankIdentifier,
                                        const QString &bankIdentifierType,
                                        const QString &secondaryIdentifier) const;

    QJsonObject buildPayeeObject(const QString &payeeName,
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
                                 const QString &secondaryIdentifier) const;

    void performUnlock();
    void setPinPromptVisible(bool visible);
    void setPinError(const QString &value);
    QString hashPin(const QString &pin, const QString &salt) const;
    bool verifyPinValue(const QString &pin) const;
    bool validateNewPin(const QString &pin, const QString &confirmPin, QString *error) const;
    void transferSavingsGoalMoney(const QString &savingsGoalUid, const QString &amount, bool addMoney);

private:
    // members
    QNetworkAccessManager m_nam;
    QString m_token;
    QString m_accountUid;
    QString m_categoryUid;
    QString m_availableBalance;
    QString m_clearedBalance;
    QString m_currency;
    QString m_status;
    bool m_busy = false;
    QVariantList m_transactionRows;
    QString m_lastUpdated;

    QString m_accountHolderName;
    QString m_accountName;
    QString m_accountNumber;
    QString m_sortCode;
    QString m_accountType;

    QString m_email;
    QString m_phone;
    QString m_postalAddress;
    QString m_countryCode;
    TokenStore m_tokenStore;

    bool m_initializing = false;
    int m_pendingRequests = 0;
    int m_startupDaysBack = 14;
    bool m_locked = false;
    QString m_navigationTarget;
    QString m_payeeWriteToken;
    QString m_apiKeyId;
    QString m_privateApiKeyPem;
    QVariantMap m_payeeDetail;
    bool m_consentPending = false;
    QString m_consentMessage;
    bool responseRequiresConsent(const QByteArray &body, QString *messageOut = 0) const;
    int m_autoLockMinutes = 2;
    bool m_lockOnBackground = true;

    QString m_pinHash;
    QString m_pinSalt;
    bool m_pinPromptVisible = false;
    QString m_pinError;
    QString m_pinSettingsError;
    QVariantMap m_paymentDraft;
    QString m_paymentPreviewJson;
    bool m_paymentPreviewReady = false;
    bool m_paymentSubmitting = false;
    bool m_paymentSubmitted = false;
    QString m_paymentResultMessage;
    QString buildIsoDateHeader() const;
    QByteArray buildDigestHeader(const QByteArray &body) const;
    QByteArray signWithRsaSha512(const QByteArray &content,
                                 const QString &privateKeyPem,
                                 QString *errorMessage) const;
    bool m_pinConfirmationPending = false;
    QVariantList m_sourceAccounts;
    QNetworkConfigurationManager m_networkConfigManager;
    bool m_online = true;

    QVariantList m_directDebitMandates;
    QVariantList m_standingOrders;
    QString m_lastFeedExportCsvPath;
    QVariantList m_spaces;

    qint64 m_availableBalanceMinorUnits = 0;
};

#endif // STARLINGCLIENT_H
