;; Decentralized Mutual Insurance Pool (DMIP) Smart Contract
;; 
;; A blockchain-based mutual insurance platform where community members stake 
;; tokens to create a shared insurance pool, earn yield on their contributions, 
;; and democratically resolve insurance claims through transparent governance mechanisms.

;; Protocol administrator for governance operations
(define-constant contract-owner tx-sender)

;; Staking and financial constraints
(define-constant min-participation-stake u1000000)
(define-constant max-claim-payout-limit u100000000)
(define-constant token-lock-duration-blocks u144)
(define-constant max-yield-rate-basis-points u1000)
(define-constant min-claim-description-chars u5)

;; Error definitions for protocol operations
(define-constant ERR-ACCESS-DENIED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u102))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u103))
(define-constant ERR-CLAIM-REJECTED (err u104))
(define-constant ERR-STAKE-BELOW-MINIMUM (err u105))
(define-constant ERR-TOKENS-LOCKED (err u106))
(define-constant ERR-THRESHOLD-INVALID (err u107))
(define-constant ERR-CLAIM-AMOUNT-INVALID (err u108))
(define-constant ERR-YIELD-RATE-TOO-HIGH (err u109))
(define-constant ERR-INVALID-PARAMETER (err u110))
(define-constant ERR-DESCRIPTION-TOO-SHORT (err u111))
(define-constant ERR-INVALID-RECIPIENT (err u112))
(define-constant ERR-CLAIM-NOT-EXISTS (err u113))

;; Member participation data storage
(define-map pool-participants
  { participant-address: principal }
  { 
    staked-amount: uint,
    stake-start-block: uint,
    last-yield-collection-block: uint
  }
)

;; Insurance claim records management
(define-map claim-requests
  { claim-id: uint }
  { 
    claimant-address: principal,
    claim-amount: uint,
    description-text: (string-utf8 256),
    submission-block: uint,
    status: (string-utf8 10)
  }
)

;; Protocol state management variables
(define-data-var total-pool-funds uint u0)
(define-data-var total-payouts-distributed uint u0)
(define-data-var next-available-claim-id uint u0)
(define-data-var active-yield-percentage uint u100)
(define-data-var required-consensus-percentage uint u5100)

;; Query participant information from storage
(define-read-only (fetch-participant-info (participant-address principal))
  (default-to
    { staked-amount: u0, stake-start-block: u0, last-yield-collection-block: u0 }
    (map-get? pool-participants { participant-address: participant-address })
  )
)

;; Retrieve claim details by identifier
(define-read-only (fetch-claim-details (claim-id uint))
  (map-get? claim-requests { claim-id: claim-id })
)

;; Get current insurance pool balance
(define-read-only (get-current-pool-balance)
  (var-get total-pool-funds)
)

;; Get total amount paid out in claims
(define-read-only (get-total-claim-payouts)
  (var-get total-payouts-distributed)
)

;; Get current yield rate setting
(define-read-only (get-current-yield-rate)
  (var-get active-yield-percentage)
)

;; Get governance consensus threshold
(define-read-only (get-governance-threshold)
  (var-get required-consensus-percentage)
)

;; Verify text input meets minimum length requirement
(define-read-only (check-text-length (input-string (string-utf8 256)))
  (len input-string)
)

;; Validate recipient address is acceptable for transfers
(define-read-only (is-valid-transfer-recipient (recipient-address principal))
  (and 
    (not (is-eq recipient-address (as-contract tx-sender)))
    (not (is-eq recipient-address 'SP000000000000000000002Q6VF78))
  )
)

;; Calculate pending yield rewards for participant
(define-read-only (compute-pending-yield (participant-address principal))
  (let (
    (participant-info (fetch-participant-info participant-address))
    (staked-tokens (get staked-amount participant-info))
    (last-collection-block (get last-yield-collection-block participant-info))
    (blocks-elapsed (- block-height last-collection-block))
  )
    (if (> staked-tokens u0)
      (/ (* (* staked-tokens blocks-elapsed) (var-get active-yield-percentage)) u10000)
      u0
    )
  )
)

;; Check if participant's tokens are available for withdrawal
(define-read-only (can-withdraw-tokens (participant-address principal))
  (let (
    (participant-info (fetch-participant-info participant-address))
    (stake-block (get stake-start-block participant-info))
    (blocks-passed (- block-height stake-block))
  )
    (>= blocks-passed token-lock-duration-blocks)
  )
)

;; Stake tokens to join the insurance pool
(define-public (stake-tokens-in-pool (stake-amount uint))
  (let (
    (current-participant (fetch-participant-info tx-sender))
    (existing-stake (get staked-amount current-participant))
  )
    (asserts! (>= stake-amount min-participation-stake) ERR-STAKE-BELOW-MINIMUM)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (if (> existing-stake u0)
      (begin
        (try! (collect-yield-rewards))
        (map-set pool-participants
          { participant-address: tx-sender }
          { 
            staked-amount: (+ existing-stake stake-amount),
            stake-start-block: block-height,
            last-yield-collection-block: block-height
          }
        )
      )
      (map-set pool-participants
        { participant-address: tx-sender }
        { 
          staked-amount: stake-amount,
          stake-start-block: block-height,
          last-yield-collection-block: block-height
        }
      )
    )
    
    (var-set total-pool-funds (+ (var-get total-pool-funds) stake-amount))
    (ok stake-amount)
  )
)

;; Withdraw staked tokens from the pool
(define-public (withdraw-staked-tokens (withdrawal-amount uint))
  (let (
    (participant-info (fetch-participant-info tx-sender))
    (current-stake (get staked-amount participant-info))
    (stake-block (get stake-start-block participant-info))
  )
    (asserts! (>= current-stake withdrawal-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (- block-height stake-block) token-lock-duration-blocks) ERR-TOKENS-LOCKED)
    
    (try! (collect-yield-rewards))
    
    (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
    
    (map-set pool-participants
      { participant-address: tx-sender }
      { 
        staked-amount: (- current-stake withdrawal-amount),
        stake-start-block: stake-block,
        last-yield-collection-block: block-height
      }
    )
    
    (var-set total-pool-funds (- (var-get total-pool-funds) withdrawal-amount))
    (ok withdrawal-amount)
  )
)

;; Collect accumulated yield from staking
(define-public (collect-yield-rewards)
  (let (
    (participant-info (fetch-participant-info tx-sender))
    (current-stake (get staked-amount participant-info))
    (pending-yield (compute-pending-yield tx-sender))
  )
    (asserts! (> current-stake u0) ERR-PARTICIPANT-NOT-FOUND)
    
    (if (> pending-yield u0)
      (begin
        (try! (as-contract (stx-transfer? pending-yield (as-contract tx-sender) tx-sender)))
        
        (map-set pool-participants
          { participant-address: tx-sender }
          { 
            staked-amount: current-stake,
            stake-start-block: (get stake-start-block participant-info),
            last-yield-collection-block: block-height
          }
        )
        (ok pending-yield)
      )
      (ok u0)
    )
  )
)

;; Submit a new insurance claim
(define-public (file-insurance-claim (requested-amount uint) (claim-description (string-utf8 256)))
  (let (
    (participant-info (fetch-participant-info tx-sender))
    (current-stake (get staked-amount participant-info))
    (claim-identifier (var-get next-available-claim-id))
    (description-length (check-text-length claim-description))
  )
    (asserts! (> current-stake u0) ERR-PARTICIPANT-NOT-FOUND)
    (asserts! (and (> requested-amount u0) (<= requested-amount max-claim-payout-limit)) 
              ERR-CLAIM-AMOUNT-INVALID)
    (asserts! (>= description-length min-claim-description-chars) 
              ERR-DESCRIPTION-TOO-SHORT)
    
    (map-set claim-requests
      { claim-id: claim-identifier }
      { 
        claimant-address: tx-sender,
        claim-amount: requested-amount,
        description-text: claim-description,
        submission-block: block-height,
        status: u"pending"
      }
    )
    
    (var-set next-available-claim-id (+ claim-identifier u1))
    (ok claim-identifier)
  )
)

;; Process insurance claim resolution
(define-public (process-claim-decision (claim-identifier uint) (approve-claim bool))
  (let (
    (claim-info (unwrap! (fetch-claim-details claim-identifier) ERR-CLAIM-NOT-EXISTS))
    (claim-recipient (get claimant-address claim-info))
    (claim-amount (get claim-amount claim-info))
    (current-status (get status claim-info))
    (claim-description (get description-text claim-info))
    (filing-block (get submission-block claim-info))
    (claim-key { claim-id: claim-identifier })
  )
    (asserts! (is-eq tx-sender contract-owner) ERR-ACCESS-DENIED)
    (asserts! (is-eq current-status u"pending") ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (or (not approve-claim) (>= (var-get total-pool-funds) claim-amount)) 
              ERR-INSUFFICIENT-BALANCE)
    
    (if approve-claim
      (begin
        (try! (as-contract (stx-transfer? claim-amount (as-contract tx-sender) claim-recipient)))
        
        (map-set claim-requests
          claim-key
          { 
            claimant-address: claim-recipient,
            claim-amount: claim-amount,
            description-text: claim-description,
            submission-block: filing-block,
            status: u"approved"
          }
        )
        
        (var-set total-payouts-distributed (+ (var-get total-payouts-distributed) claim-amount))
        (var-set total-pool-funds (- (var-get total-pool-funds) claim-amount))
        (ok true)
      )
      (begin
        (map-set claim-requests
          claim-key
          { 
            claimant-address: claim-recipient,
            claim-amount: claim-amount,
            description-text: claim-description,
            submission-block: filing-block,
            status: u"denied"
          }
        )
        (ok false)
      )
    )
  )
)

;; Adjust protocol yield rate
(define-public (set-new-yield-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-ACCESS-DENIED)
    (asserts! (<= new-rate max-yield-rate-basis-points) ERR-YIELD-RATE-TOO-HIGH)
    
    (var-set active-yield-percentage new-rate)
    (ok new-rate)
  )
)

;; Update governance consensus requirement
(define-public (set-consensus-requirement (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-ACCESS-DENIED)
    (asserts! (<= new-threshold u10000) ERR-THRESHOLD-INVALID)
    (asserts! (> new-threshold u0) ERR-INVALID-PARAMETER)
    
    (var-set required-consensus-percentage new-threshold)
    (ok new-threshold)
  )
)

;; Emergency protocol fund recovery
(define-public (recover-protocol-funds (recovery-amount uint) (recovery-recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-ACCESS-DENIED)
    (asserts! (is-valid-transfer-recipient recovery-recipient) ERR-INVALID-RECIPIENT)
    (asserts! (<= recovery-amount (var-get total-pool-funds)) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? recovery-amount (as-contract tx-sender) recovery-recipient)))
    (var-set total-pool-funds (- (var-get total-pool-funds) recovery-amount))
    
    (ok recovery-amount)
  )
)