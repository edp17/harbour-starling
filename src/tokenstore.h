#ifndef TOKENSTORE_H
#define TOKENSTORE_H

#include <QString>

class TokenStore
{
public:
    TokenStore();

    QString loadToken() const;
    bool saveToken(const QString &token);
    bool clearToken();

    QString loadPayeeWriteToken() const;
    bool savePayeeWriteToken(const QString &token);
    bool clearPayeeWriteToken();

    QString loadApiKeyId() const;
    bool saveApiKeyId(const QString &value);
    bool clearApiKeyId();

    QString loadPrivateApiKeyPem() const;
    bool savePrivateApiKeyPem(const QString &value);
    bool clearPrivateApiKeyPem();

    bool hasStoredTokenFlag() const;
    void setStoredTokenFlag(bool value);

    bool hasStoredPayeeWriteTokenFlag() const;
    void setStoredPayeeWriteTokenFlag(bool value);

    bool hasStoredApiKeyIdFlag() const;
    void setStoredApiKeyIdFlag(bool value);

    bool hasStoredPrivateApiKeyPemFlag() const;
    void setStoredPrivateApiKeyPemFlag(bool value);

    QString lastError() const;

    QString loadPhysicalCard() const;
    bool savePhysicalCard(const QString &json);
    bool clearPhysicalCard();

    QString loadPhysicalCardPin() const;
    bool savePhysicalCardPin(const QString &pin);
    bool clearPhysicalCardPin();

    QString loadPhysicalCardCvv() const;
    bool savePhysicalCardCvv(const QString &cvv);
    bool clearPhysicalCardCvv();

private:
    QString loadSecret(const QString &secretName) const;
    bool saveSecret(const QString &secretName, const QString &token);
    bool clearSecret(const QString &secretName);

    bool readFlag(const QString &key) const;
    void writeFlag(const QString &key, bool value);

    void setError(const QString &error) const;

private:
    mutable QString m_lastError;
};

#endif // TOKENSTORE_H
