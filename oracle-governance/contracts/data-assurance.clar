;; Cross-Chain Oracle Smart Contract
;; This contract implements a decentralized oracle network that allows registered providers 
;; to submit and validate cross-chain data. It includes reputation management, staking mechanisms,
;; governance features, and a slashing protocol to maintain data integrity and provider accountability.

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-INVALID-DATA-FORMAT (err u2))
(define-constant ERR-INSUFFICIENT-STAKE-FUNDS (err u3))
(define-constant ERR-PROVIDER-REGISTRATION-EXISTS (err u4))
(define-constant ERR-DATA-EXPIRED (err u5))
(define-constant ERR-INVALID-PROPOSAL-TYPE (err u6))
(define-constant ERR-INVALID-PARAMETER-VALUE (err u7))
(define-constant ERR-INVALID-HEIGHT-VALUE (err u8))

;; Data Maps
;; Oracle provider information storage
(define-map oracle-provider-registry 
  principal 
  { 
    provider-reputation: uint,
    provider-stake: uint,
    provider-active-status: bool,
    provider-submission-count: uint,
    provider-successful-submissions: uint
  }
)

;; Oracle data storage with comprehensive metadata
(define-map oracle-data-records 
  (string-ascii 50)  
  { 
    data-value: (string-ascii 200), 
    data-provider: principal,
    submission-timestamp: uint,
    data-expiration-time: uint
  }
)

;; Network governance proposals
(define-map governance-proposals
  uint
  {
    proposal-description: (string-ascii 50),
    proposal-parameter-value: uint,
    total-vote-count: uint,
    affirmative-votes: uint,
    negative-votes: uint,
    proposal-active-status: bool
  }
)

;; Provider authorization registry with performance metrics
(define-map authorized-provider-registry 
  principal 
  { 
    provider-reputation-score: uint, 
    provider-submission-count: uint, 
    provider-successful-validations: uint 
  }
)

;; Data Variables
;; Community rewards pool from slashed stakes
(define-data-var community-rewards-pool uint u0)

;; Proposal tracking counter
(define-data-var governance-proposal-counter uint u0)

;; Block height simulation for testing
(define-data-var simulated-block-height uint u0)

;; Valid proposal types
(define-map valid-proposal-types 
  (string-ascii 50) 
  bool
)

;; Initialize valid proposal types
(map-set valid-proposal-types "change-min-stake" true)
(map-set valid-proposal-types "adjust-reputation" true)
(map-set valid-proposal-types "modify-rewards" true)
(map-set valid-proposal-types "update-expiry" true)

;; Read-Only Functions
;; Retrieve oracle data by key
(define-read-only (get-oracle-data (data-identifier (string-ascii 50)))
  (map-get? oracle-data-records data-identifier)
)

;; Get current simulated block height
(define-read-only (get-current-block-height)
  (var-get simulated-block-height)
)

;; Check if proposal type is valid
(define-read-only (is-valid-proposal-type (proposal-type (string-ascii 50)))
  (default-to false (map-get? valid-proposal-types proposal-type))
)

;; Provider Management Functions
;; Register as a new oracle provider
(define-public (register-new-provider (initial-stake-amount uint))
  (begin
    ;; Prevent duplicate registrations
    (asserts! (is-none (map-get? oracle-provider-registry tx-sender)) ERR-PROVIDER-REGISTRATION-EXISTS)

    ;; Enforce minimum stake requirement
    (asserts! (>= initial-stake-amount u1000) ERR-INSUFFICIENT-STAKE-FUNDS)

    ;; Transfer initial stake to contract
    (try! (stx-transfer? initial-stake-amount tx-sender (as-contract tx-sender)))

    ;; Create provider record
    (map-set oracle-provider-registry tx-sender {
      provider-reputation: u100,
      provider-stake: initial-stake-amount,
      provider-active-status: true,
      provider-submission-count: u0,
      provider-successful-submissions: u0
    })

    (ok true)
  )
)

;; Increase provider reputation through staking
(define-public (increase-provider-reputation (stake-amount uint))
  (let (
    (provider-balance (stx-get-balance tx-sender))
  )
  (begin
    ;; Verify sufficient balance
    (asserts! (>= provider-balance stake-amount) ERR-INSUFFICIENT-STAKE-FUNDS)

    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

    ;; Update provider reputation
    (let (
      (provider-data (unwrap! 
        (map-get? authorized-provider-registry tx-sender) 
        ERR-UNAUTHORIZED-ACCESS
      ))
    )
      (map-set authorized-provider-registry tx-sender (merge provider-data {
        provider-reputation-score: (+ (get provider-reputation-score provider-data) (/ stake-amount u100))
      }))
    )

    (ok true)
  ))
)

;; Governance Functions
;; Submit new governance proposal
(define-public (submit-governance-proposal 
  (proposal-type (string-ascii 50))
  (parameter-value uint)
)
  (let (
    (proposal-id (var-get governance-proposal-counter))
  )
  (begin
    ;; Restrict proposal creation to contract owner
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate proposal type
    (asserts! (is-valid-proposal-type proposal-type) ERR-INVALID-PROPOSAL-TYPE)
    
    ;; Validate parameter value based on proposal type
    (asserts! 
      (if (is-eq proposal-type "change-min-stake")
        (> parameter-value u0)  ;; Min stake must be positive
        (if (is-eq proposal-type "adjust-reputation")
          (<= parameter-value u1000)  ;; Max reputation score is 1000
          (if (is-eq proposal-type "modify-rewards")
            (<= parameter-value u100)  ;; Max reward percentage is 100
            (< parameter-value u10000)  ;; Expiry blocks under 10000
          )
        )
      )
      ERR-INVALID-PARAMETER-VALUE
    )

    ;; Record new proposal
    (map-set governance-proposals proposal-id {
      proposal-description: proposal-type,
      proposal-parameter-value: parameter-value,
      total-vote-count: u0,
      affirmative-votes: u0,
      negative-votes: u0,
      proposal-active-status: true
    })

    ;; Update proposal counter
    (var-set governance-proposal-counter (+ proposal-id u1))

    (ok proposal-id)
  ))
)

;; Penalize provider for incorrect data
(define-public (penalize-malicious-provider 
  (provider-address principal)
  (penalty-amount uint)
)
  (let (
    (provider-data (unwrap! 
      (map-get? oracle-provider-registry provider-address) 
      ERR-UNAUTHORIZED-ACCESS
    ))
    (current-provider-stake (get provider-stake provider-data))
  )
  (begin
    ;; Only contract owner can penalize providers
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED-ACCESS)

    ;; Ensure penalty doesn't exceed available stake
    (asserts! (<= penalty-amount current-provider-stake) ERR-INSUFFICIENT-STAKE-FUNDS)

    ;; Update provider record with reduced stake and reputation
    (map-set oracle-provider-registry provider-address (merge provider-data {
      provider-stake: (- current-provider-stake penalty-amount),
      provider-reputation: (/ (get provider-reputation provider-data) u2)
    }))

    ;; Add penalized funds to community pool
    (var-set community-rewards-pool (+ (var-get community-rewards-pool) penalty-amount))

    (ok true)
  ))
)

;; Reward Distribution Functions
;; Distribute rewards from community pool
(define-public (distribute-community-rewards)
  (let (
    (available-rewards (var-get community-rewards-pool))
    (provider-data (unwrap! 
      (map-get? oracle-provider-registry tx-sender) 
      ERR-UNAUTHORIZED-ACCESS
    ))
  )
  (begin
    ;; Verify provider has sufficient reputation
    (asserts! (>= (get provider-reputation provider-data) u50) ERR-UNAUTHORIZED-ACCESS)

    ;; Transfer available rewards
    (try! (as-contract (stx-transfer? available-rewards tx-sender tx-sender)))

    ;; Reset community rewards pool
    (var-set community-rewards-pool u0)

    (ok true)
  ))
)

;; Block Height Management Functions
;; Increment simulated block height
(define-public (increment-simulated-height)
  (begin
    (var-set simulated-block-height 
      (+ (var-get simulated-block-height) u1)
    )
    (ok true)
  )
)

;; Set specific block height for testing
(define-public (set-simulated-block-height (height-value uint))
  (begin
    ;; Add validation to ensure height-value is within reasonable bounds
    (asserts! (< height-value u1000000) ERR-INVALID-HEIGHT-VALUE)
    
    (var-set simulated-block-height height-value)
    (ok true)
  )
)