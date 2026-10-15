# Security and data protection requirements (excerpt)

| Document | KR-SEC-DIARY |
| --- | --- |
| Version | 1.4, binding |
| Scope | Sharing of diary data with treating physicians |

Diary entries are health data, a special category of personal data. This document is a
simplified excerpt of the requirements we work under as a medical device. The key words MUST,
MUST NOT and SHOULD are to be interpreted as described in RFC 2119.

Not every requirement in this excerpt applies to every feature. Assessing which ones apply is
part of the work (see O.Doc_1).

## 1 Purpose (O.Purp)

**O.Purp_1** Before the data subject consents to a disclosure, the application MUST show them
the recipient, the categories of data and the period that the disclosure covers.

## 2 Consent (O.Cons)

**O.Cons_1** The application MUST disclose health data to a third party only while a valid
consent of the data subject is in effect for exactly these data.

**O.Cons_2** The data subject MUST be able to withdraw a consent at any time. A withdrawal MUST
take effect for every access that begins after it.

**O.Cons_3** For every consent, the manufacturer MUST be able to show which wording the data
subject agreed to, for example by storing the version of the consent text.

## 3 Authentication (O.Auth, O.Pass)

**O.Auth_1** Before health data is disclosed to a third party, the application MUST require the
data subject to authenticate again if their last authentication is older than 15 minutes.

**O.Pass_1** Passwords MUST be at least 12 characters long and MUST be checked against a list
of known compromised passwords.

## 4 Logging (O.Log)

**O.Log_1** Every access to health data by a third party MUST be recorded with at least the
accessing party, the data accessed and the time of access.

**O.Log_2** The data subject MUST be able to view the records under O.Log_1 that concern them.

**O.Log_3** Records under O.Log_1 MUST be retained for ten years and MUST be protected against
modification.

**O.Log_4** Application logs MUST NOT contain health data or direct identifiers such as names or
email addresses.

## 5 Monitoring (O.Mon)

**O.Mon_1** Security-relevant events MUST be monitored, at least denied access attempts, consent
changes and failures to record an access under O.Log_1. A failure to record an access MUST
trigger an alert.

## 6 Error handling (O.Err)

**O.Err_1** Error responses MUST NOT reveal internal details such as stack traces, SQL
statements, file paths or library versions.

## 7 Cryptography (O.Cryp)

**O.Cryp_1** Health data MUST be encrypted at rest using a method approved by the security
officer.

## 8 Erasure (O.Del)

Stretch goal: not required for this task.

**O.Del_1** The data subject MUST be able to have their health data erased.

## 9 Traceability (O.Doc)

**O.Doc_1** For each requirement in this document, the manufacturer MUST state whether it
applies to the feature and, if it applies, where it is met (implementation and test) or why it
is not met. For this task, document it in `NOTES.md`.
