;; Grant Application Contract
;; Assists with funding proposal preparation and submission

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ORGANIZATION-NOT-FOUND (err u101))
(define-constant ERR-GRANT-NOT-FOUND (err u108))
(define-constant ERR-INVALID-INPUT (err u104))
(define-constant ERR-DEADLINE-PASSED (err u106))
(define-constant ERR-DUPLICATE-ENTRY (err u109))

;; Application status constants
(define-constant STATUS-DRAFT u1)
(define-constant STATUS-SUBMITTED u2)
(define-constant STATUS-UNDER-REVIEW u3)
(define-constant STATUS-APPROVED u4)
(define-constant STATUS-REJECTED u5)
(define-constant STATUS-WITHDRAWN u6)

;; Grant type constants
(define-constant TYPE-OPERATING u1)
(define-constant TYPE-PROJECT u2)
(define-constant TYPE-CAPACITY u3)
(define-constant TYPE-RESEARCH u4)
(define-constant TYPE-EMERGENCY u5)

;; Data Variables
(define-data-var next-application-id uint u1)
(define-data-var next-foundation-id uint u1)
(define-data-var next-template-id uint u1)

;; Data Maps
(define-map grant-foundations
  { foundation-id: uint }
  {
    name: (string-ascii 100),
    focus-areas: (list 10 (string-ascii 50)),
    min-grant-amount: uint,
    max-grant-amount: uint,
    application-deadline: uint,
    decision-timeline: uint,
    requirements: (string-ascii 1000),
    contact-info: (string-ascii 200),
    is-active: bool
  }
)

(define-map grant-applications
  { application-id: uint }
  {
    organization-id: (string-ascii 50),
    foundation-id: uint,
    project-title: (string-ascii 200),
    requested-amount: uint,
    project-duration: uint,
    grant-type: uint,
    submission-date: uint,
    deadline: uint,
    status: uint,
    reviewer-notes: (string-ascii 1000),
    score: uint
  }
)

(define-map application-documents
  { application-id: uint, document-type: (string-ascii 50) }
  {
    document-name: (string-ascii 100),
    document-hash: (string-ascii 64),
    upload-date: uint,
    file-size: uint,
    is-required: bool,
    is-submitted: bool
  }
)

(define-map grant-templates
  { template-id: uint }
  {
    template-name: (string-ascii 100),
    grant-type: uint,
    sections: (list 20 (string-ascii 100)),
    required-documents: (list 15 (string-ascii 50)),
    word-limits: (list 20 uint),
    best-practices: (string-ascii 2000),
    success-rate: uint
  }
)

(define-map application-reviews
  { application-id: uint, reviewer-id: (string-ascii 50) }
  {
    review-date: uint,
    technical-score: uint,
    impact-score: uint,
    feasibility-score: uint,
    budget-score: uint,
    overall-score: uint,
    comments: (string-ascii 1000),
    recommendation: uint
  }
)

(define-map organization-grant-history
  { organization-id: (string-ascii 50) }
  {
    total-applications: uint,
    approved-applications: uint,
    total-awarded: uint,
    success-rate: uint,
    average-award-size: uint,
    last-application-date: uint
  }
)

(define-map grant-requirements
  { foundation-id: uint, requirement-type: (string-ascii 50) }
  {
    description: (string-ascii 500),
    is-mandatory: bool,
    weight: uint,
    evaluation-criteria: (string-ascii 300)
  }
)

;; Authorization Functions
(define-private (is-authorized (organization-id (string-ascii 50)))
  (or
    (is-eq tx-sender CONTRACT-OWNER)
    (is-eq tx-sender CONTRACT-OWNER)
  )
)

;; Foundation Management Functions
(define-public (register-foundation
  (name (string-ascii 100))
  (focus-areas (list 10 (string-ascii 50)))
  (min-grant-amount uint)
  (max-grant-amount uint)
  (application-deadline uint)
  (decision-timeline uint)
  (requirements (string-ascii 1000))
  (contact-info (string-ascii 200))
)
  (let ((foundation-id (var-get next-foundation-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (< min-grant-amount max-grant-amount) ERR-INVALID-INPUT)
    (asserts! (> application-deadline block-height) ERR-INVALID-INPUT)

    (map-set grant-foundations
      { foundation-id: foundation-id }
      {
        name: name,
        focus-areas: focus-areas,
        min-grant-amount: min-grant-amount,
        max-grant-amount: max-grant-amount,
        application-deadline: application-deadline,
        decision-timeline: decision-timeline,
        requirements: requirements,
        contact-info: contact-info,
        is-active: true
      }
    )

    (var-set next-foundation-id (+ foundation-id u1))
    (ok foundation-id)
  )
)

(define-public (update-foundation-status (foundation-id uint) (is-active bool))
  (let ((foundation (unwrap! (map-get? grant-foundations { foundation-id: foundation-id })
    ERR-GRANT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set grant-foundations
      { foundation-id: foundation-id }
      (merge foundation { is-active: is-active })
    )
    (ok is-active)
  )
)

;; Application Management Functions
(define-public (create-application
  (organization-id (string-ascii 50))
  (foundation-id uint)
  (project-title (string-ascii 200))
  (requested-amount uint)
  (project-duration uint)
  (grant-type uint)
)
  (let
    (
      (application-id (var-get next-application-id))
      (foundation (unwrap! (map-get? grant-foundations { foundation-id: foundation-id })
        ERR-GRANT-NOT-FOUND))
    )
    (asserts! (is-authorized organization-id) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active foundation) ERR-GRANT-NOT-FOUND)
    (asserts! (> (len project-title) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= requested-amount (get min-grant-amount foundation))
      (<= requested-amount (get max-grant-amount foundation))) ERR-INVALID-INPUT)
    (asserts! (and (>= grant-type TYPE-OPERATING) (<= grant-type TYPE-EMERGENCY)) ERR-INVALID-INPUT)
    (asserts! (> (get application-deadline foundation) block-height) ERR-DEADLINE-PASSED)

    (map-set grant-applications
      { application-id: application-id }
      {
        organization-id: organization-id,
        foundation-id: foundation-id,
        project-title: project-title,
        requested-amount: requested-amount,
        project-duration: project-duration,
        grant-type: grant-type,
        submission-date: u0,
        deadline: (get application-deadline foundation),
        status: STATUS-DRAFT,
        reviewer-notes: "",
        score: u0
      }
    )

    ;; Initialize organization grant history if needed
    (if (is-none (map-get? organization-grant-history { organization-id: organization-id }))
      (map-set organization-grant-history
        { organization-id: organization-id }
        {
          total-applications: u0,
          approved-applications: u0,
          total-awarded: u0,
          success-rate: u0,
          average-award-size: u0,
          last-application-date: u0
        }
      )
      true
    )

    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

(define-public (submit-application (application-id uint))
  (let ((application (unwrap! (map-get? grant-applications { application-id: application-id })
    ERR-GRANT-NOT-FOUND)))
    (asserts! (is-authorized (get organization-id application)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application) STATUS-DRAFT) ERR-INVALID-INPUT)
    (asserts! (> (get deadline application) block-height) ERR-DEADLINE-PASSED)

    ;; Check if all required documents are submitted
    (asserts! (all-required-documents-submitted application-id) ERR-INVALID-INPUT)

    (map-set grant-applications
      { application-id: application-id }
      (merge application {
        submission-date: block-height,
        status: STATUS-SUBMITTED
      })
    )

    ;; Update organization history
    (let ((history (unwrap! (map-get? organization-grant-history
      { organization-id: (get organization-id application) }) ERR-ORGANIZATION-NOT-FOUND)))
      (map-set organization-grant-history
        { organization-id: (get organization-id application) }
        (merge history {
          total-applications: (+ (get total-applications history) u1),
          last-application-date: block-height
        })
      )
    )

    (ok STATUS-SUBMITTED)
  )
)

(define-private (all-required-documents-submitted (application-id uint))
  ;; This would check if all required documents are uploaded
  ;; Simplified implementation returns true
  true
)

(define-public (update-application-status
  (application-id uint)
  (new-status uint)
  (reviewer-notes (string-ascii 1000))
)
  (let ((application (unwrap! (map-get? grant-applications { application-id: application-id })
    ERR-GRANT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-status STATUS-DRAFT) (<= new-status STATUS-WITHDRAWN)) ERR-INVALID-INPUT)

    (map-set grant-applications
      { application-id: application-id }
      (merge application {
        status: new-status,
        reviewer-notes: reviewer-notes
      })
    )

    ;; Update organization history if approved
    (if (is-eq new-status STATUS-APPROVED)
      (let ((history (unwrap! (map-get? organization-grant-history
        { organization-id: (get organization-id application) }) ERR-ORGANIZATION-NOT-FOUND)))
        (let
          (
            (new-approved (+ (get approved-applications history) u1))
            (new-total-awarded (+ (get total-awarded history) (get requested-amount application)))
            (new-success-rate (/ (* new-approved u100) (get total-applications history)))
            (new-average-award (/ new-total-awarded new-approved))
          )
          (map-set organization-grant-history
            { organization-id: (get organization-id application) }
            (merge history {
              approved-applications: new-approved,
              total-awarded: new-total-awarded,
              success-rate: new-success-rate,
              average-award-size: new-average-award
            })
          )
        )
      )
      true
    )

    (ok new-status)
  )
)

;; Document Management Functions
(define-public (upload-document
  (application-id uint)
  (document-type (string-ascii 50))
  (document-name (string-ascii 100))
  (document-hash (string-ascii 64))
  (file-size uint)
  (is-required bool)
)
  (let ((application (unwrap! (map-get? grant-applications { application-id: application-id })
    ERR-GRANT-NOT-FOUND)))
    (asserts! (is-authorized (get organization-id application)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len document-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len document-hash) u0) ERR-INVALID-INPUT)

    (map-set application-documents
      { application-id: application-id, document-type: document-type }
      {
        document-name: document-name,
        document-hash: document-hash,
        upload-date: block-height,
        file-size: file-size,
        is-required: is-required,
        is-submitted: true
      }
    )
    (ok true)
  )
)

;; Template Management Functions
(define-public (create-grant-template
  (template-name (string-ascii 100))
  (grant-type uint)
  (sections (list 20 (string-ascii 100)))
  (required-documents (list 15 (string-ascii 50)))
  (word-limits (list 20 uint))
  (best-practices (string-ascii 2000))
)
  (let ((template-id (var-get next-template-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len template-name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= grant-type TYPE-OPERATING) (<= grant-type TYPE-EMERGENCY)) ERR-INVALID-INPUT)

    (map-set grant-templates
      { template-id: template-id }
      {
        template-name: template-name,
        grant-type: grant-type,
        sections: sections,
        required-documents: required-documents,
        word-limits: word-limits,
        best-practices: best-practices,
        success-rate: u0
      }
    )

    (var-set next-template-id (+ template-id u1))
    (ok template-id)
  )
)
