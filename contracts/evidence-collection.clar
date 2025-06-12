;; Evidence Collection Contract
;; Manages the collection and storage of compliance evidence

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_EVIDENCE_NOT_FOUND (err u301))
(define-constant ERR_INVALID_TRAIL (err u302))
(define-constant ERR_EVIDENCE_SEALED (err u303))

;; Evidence types
(define-constant EVIDENCE_DOCUMENT u0)
(define-constant EVIDENCE_SCREENSHOT u1)
(define-constant EVIDENCE_LOG u2)
(define-constant EVIDENCE_TESTIMONY u3)

;; Evidence status
(define-constant EVIDENCE_DRAFT u0)
(define-constant EVIDENCE_SUBMITTED u1)
(define-constant EVIDENCE_SEALED u2)

;; Data structures
(define-map evidence-items
  { evidence-id: uint }
  {
    trail-id: uint,
    collector: principal,
    evidence-type: uint,
    title: (string-ascii 200),
    description: (string-ascii 500),
    hash: (string-ascii 64),
    timestamp: uint,
    status: uint
  }
)

(define-map evidence-metadata
  { evidence-id: uint }
  {
    file-size: uint,
    mime-type: (string-ascii 100),
    chain-of-custody: (list 10 principal)
  }
)

(define-map trail-evidence-count
  { trail-id: uint }
  { count: uint }
)

(define-data-var next-evidence-id uint u1)

;; Public functions
(define-public (collect-evidence
  (trail-id uint)
  (evidence-type uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (hash (string-ascii 64))
  (file-size uint)
  (mime-type (string-ascii 100))
)
  (let ((evidence-id (var-get next-evidence-id))
        (collector tx-sender))
    ;; Would verify trail exists and collector is authorized
    (map-set evidence-items
      { evidence-id: evidence-id }
      {
        trail-id: trail-id,
        collector: collector,
        evidence-type: evidence-type,
        title: title,
        description: description,
        hash: hash,
        timestamp: block-height,
        status: EVIDENCE_DRAFT
      }
    )
    (map-set evidence-metadata
      { evidence-id: evidence-id }
      {
        file-size: file-size,
        mime-type: mime-type,
        chain-of-custody: (list collector)
      }
    )
    ;; Update trail evidence count
    (match (map-get? trail-evidence-count { trail-id: trail-id })
      current-count (map-set trail-evidence-count
        { trail-id: trail-id }
        { count: (+ (get count current-count) u1) }
      )
      (map-set trail-evidence-count
        { trail-id: trail-id }
        { count: u1 }
      )
    )
    (var-set next-evidence-id (+ evidence-id u1))
    (ok evidence-id)
  )
)

(define-public (submit-evidence (evidence-id uint))
  (let ((evidence-data (unwrap! (map-get? evidence-items { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get collector evidence-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status evidence-data) EVIDENCE_DRAFT) ERR_EVIDENCE_SEALED)
    (map-set evidence-items
      { evidence-id: evidence-id }
      (merge evidence-data { status: EVIDENCE_SUBMITTED })
    )
    (ok true)
  )
)

(define-public (seal-evidence (evidence-id uint))
  (let ((evidence-data (unwrap! (map-get? evidence-items { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get collector evidence-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status evidence-data) EVIDENCE_SUBMITTED) ERR_EVIDENCE_SEALED)
    (map-set evidence-items
      { evidence-id: evidence-id }
      (merge evidence-data { status: EVIDENCE_SEALED })
    )
    (ok true)
  )
)

(define-public (transfer-custody (evidence-id uint) (new-custodian principal))
  (let ((evidence-data (unwrap! (map-get? evidence-items { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND))
        (metadata (unwrap! (map-get? evidence-metadata { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get collector evidence-data)) ERR_UNAUTHORIZED)
    (map-set evidence-metadata
      { evidence-id: evidence-id }
      (merge metadata
        { chain-of-custody: (unwrap-panic (as-max-len? (append (get chain-of-custody metadata) new-custodian) u10)) }
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-evidence-info (evidence-id uint))
  (map-get? evidence-items { evidence-id: evidence-id })
)

(define-read-only (get-evidence-metadata (evidence-id uint))
  (map-get? evidence-metadata { evidence-id: evidence-id })
)

(define-read-only (get-trail-evidence-count (trail-id uint))
  (default-to { count: u0 } (map-get? trail-evidence-count { trail-id: trail-id }))
)

(define-read-only (verify-evidence-hash (evidence-id uint) (provided-hash (string-ascii 64)))
  (match (map-get? evidence-items { evidence-id: evidence-id })
    evidence-data (is-eq (get hash evidence-data) provided-hash)
    false
  )
)
