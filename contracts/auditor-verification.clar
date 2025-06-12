;; Auditor Verification Contract
;; Manages the verification and authorization of compliance auditors

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_AUDITOR_EXISTS (err u101))
(define-constant ERR_AUDITOR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Auditor status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map auditors
  { auditor: principal }
  {
    status: uint,
    verification-date: uint,
    certifications: (string-ascii 500),
    specializations: (string-ascii 300)
  }
)

(define-map auditor-stats
  { auditor: principal }
  {
    total-audits: uint,
    successful-audits: uint,
    rating: uint
  }
)

(define-data-var next-auditor-id uint u1)

;; Public functions
(define-public (register-auditor (certifications (string-ascii 500)) (specializations (string-ascii 300)))
  (let ((auditor tx-sender))
    (asserts! (is-none (map-get? auditors { auditor: auditor })) ERR_AUDITOR_EXISTS)
    (map-set auditors
      { auditor: auditor }
      {
        status: STATUS_PENDING,
        verification-date: block-height,
        certifications: certifications,
        specializations: specializations
      }
    )
    (map-set auditor-stats
      { auditor: auditor }
      {
        total-audits: u0,
        successful-audits: u0,
        rating: u0
      }
    )
    (ok true)
  )
)

(define-public (verify-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? auditors { auditor: auditor })) ERR_AUDITOR_NOT_FOUND)
    (map-set auditors
      { auditor: auditor }
      (merge (unwrap-panic (map-get? auditors { auditor: auditor }))
        { status: STATUS_VERIFIED, verification-date: block-height }
      )
    )
    (ok true)
  )
)

(define-public (update-auditor-status (auditor principal) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? auditors { auditor: auditor })) ERR_AUDITOR_NOT_FOUND)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (map-set auditors
      { auditor: auditor }
      (merge (unwrap-panic (map-get? auditors { auditor: auditor }))
        { status: new-status }
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-auditor-info (auditor principal))
  (map-get? auditors { auditor: auditor })
)

(define-read-only (get-auditor-stats (auditor principal))
  (map-get? auditor-stats { auditor: auditor })
)

(define-read-only (is-verified-auditor (auditor principal))
  (match (map-get? auditors { auditor: auditor })
    auditor-data (is-eq (get status auditor-data) STATUS_VERIFIED)
    false
  )
)
