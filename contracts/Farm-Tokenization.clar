;; Farm Tokenization Smart Contract with Integrated Farm Insurance
;; Clarity v3 compliant with comprehensive error handling

;; ========================================
;; CONSTANTS AND ERROR CODES
;; ========================================

;; Core contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-no-earnings (err u104))
(define-constant err-insufficient-shares (err u105))
(define-constant err-invalid-duration (err u106))
(define-constant err-stake-active (err u107))
(define-constant err-stake-locked (err u108))

;; Insurance-specific error constants
(define-constant err-policy-not-found (err u201))
(define-constant err-policy-expired (err u202))
(define-constant err-insufficient-coverage (err u203))
(define-constant err-claim-already-filed (err u204))
(define-constant err-invalid-claim-amount (err u205))
(define-constant err-unauthorized-claim (err u206))
(define-constant err-policy-inactive (err u207))

;; ========================================
;; DATA VARIABLES
;; ========================================

(define-data-var total-farms uint u0)
(define-data-var total-policies uint u0)
(define-data-var total-claims uint u0)

;; ========================================
;; CORE FARM TOKENIZATION DATA MAPS
;; ========================================

(define-map Farms
    uint
    {
        farm-id: uint,
        owner: principal,
        total-shares: uint,
        available-shares: uint,
        price-per-share: uint,
        location: (string-ascii 64),
        size: uint,
        verified: bool,
    }
)

(define-map FarmShares
    {
        farm-id: uint,
        investor: principal,
    }
    { shares: uint }
)

(define-map InvestorPortfolio
    principal
    (list 50 uint)
)

(define-map FarmRevenue
    uint
    { total-distributed: uint }
)

(define-map InvestorEarnings
    {
        farm-id: uint,
        investor: principal,
    }
    { earnings: uint }
)

(define-map StakedShares
    {
        farm-id: uint,
        investor: principal,
    }
    {
        staked-amount: uint,
        stake-start: uint,
        stake-duration: uint,
        reward-multiplier: uint,
    }
)

(define-map StakingRewards
    {
        farm-id: uint,
        investor: principal,
    }
    { total-rewards: uint }
)

;; ========================================
;; INSURANCE FEATURE DATA MAPS
;; ========================================

(define-map InsurancePolicies
    uint
    {
        policy-id: uint,
        farm-id: uint,
        owner: principal,
        policy-type: (string-ascii 20),
        coverage-amount: uint,
        premium: uint,
        start-date: uint,
        end-date: uint,
        active: bool,
    }
)

(define-map InsuranceClaims
    uint
    {
        claim-id: uint,
        policy-id: uint,
        claimant: principal,
        claim-amount: uint,
        claim-reason: (string-ascii 200),
        status: (string-ascii 10),
        filed-date: uint,
        processed-date: (optional uint),
    }
)

(define-map RiskFactors
    (string-ascii 64)
    { risk-multiplier: uint }
)

(define-map PolicyPremiumPool
    uint
    { total-premiums: uint }
)

(define-map ClaimHistory
    {
        farm-id: uint,
        policy-type: (string-ascii 20),
    }
    { claim-count: uint }
)

;; ========================================
;; CORE FARM TOKENIZATION FUNCTIONS
;; ========================================

(define-public (register-farm
        (location (string-ascii 64))
        (total-shares uint)
        (price-per-share uint)
        (size uint)
    )
    (let ((farm-id (+ (var-get total-farms) u1)))
        (asserts! (> total-shares u0) err-invalid-amount)
        (asserts! (> price-per-share u0) err-invalid-amount)
        (asserts! (> size u0) err-invalid-amount)
        (map-set Farms farm-id {
            farm-id: farm-id,
            owner: tx-sender,
            total-shares: total-shares,
            available-shares: total-shares,
            price-per-share: price-per-share,
            location: location,
            size: size,
            verified: false,
        })
        (var-set total-farms farm-id)
        (ok farm-id)
    )
)

(define-public (verify-farm (farm-id uint))
    (let ((farm (unwrap! (map-get? Farms farm-id) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set Farms farm-id (merge farm { verified: true }))
        (ok true)
    )
)

(define-public (purchase-shares
        (farm-id uint)
        (share-count uint)
    )
    (let (
            (farm (unwrap! (map-get? Farms farm-id) err-not-found))
            (total-cost (* share-count (get price-per-share farm)))
        )
        (asserts! (>= (get available-shares farm) share-count) err-invalid-amount)
        (asserts! (get verified farm) err-unauthorized)
        (try! (stx-transfer? total-cost tx-sender (get owner farm)))
        (map-set Farms farm-id
            (merge farm { available-shares: (- (get available-shares farm) share-count) })
        )
        (map-set FarmShares {
            farm-id: farm-id,
            investor: tx-sender,
        } { shares: (+
            (default-to u0
                (get shares
                    (map-get? FarmShares {
                        farm-id: farm-id,
                        investor: tx-sender,
                    })
                ))
            share-count
        ) }
        )
        (update-investor-portfolio farm-id)
        (ok true)
    )
)

(define-public (transfer-shares
        (farm-id uint)
        (recipient principal)
        (share-count uint)
    )
    (let (
            (sender-shares (unwrap!
                (map-get? FarmShares {
                    farm-id: farm-id,
                    investor: tx-sender,
                })
                err-not-found
            ))
            (recipient-shares (default-to { shares: u0 }
                (map-get? FarmShares {
                    farm-id: farm-id,
                    investor: recipient,
                })
            ))
        )
        (asserts! (>= (get shares sender-shares) share-count) err-invalid-amount)
        (map-set FarmShares {
            farm-id: farm-id,
            investor: tx-sender,
        } { shares: (- (get shares sender-shares) share-count) }
        )
        (map-set FarmShares {
            farm-id: farm-id,
            investor: recipient,
        } { shares: (+ (get shares recipient-shares) share-count) }
        )
        (update-investor-portfolio farm-id)
        (ok true)
    )
)

(define-private (update-investor-portfolio (farm-id uint))
    (let ((current-portfolio (default-to (list) (map-get? InvestorPortfolio tx-sender))))
        (if (< (len current-portfolio) u50)
            (if (is-none (index-of current-portfolio farm-id))
                (match (as-max-len? (append current-portfolio farm-id) u50)
                    new-portfolio (map-set InvestorPortfolio tx-sender new-portfolio)
                    true
                )
                true
            )
            true
        )
        true
    )
)

(define-public (distribute-revenue
        (farm-id uint)
        (amount uint)
    )
    (let (
            (farm (unwrap! (map-get? Farms farm-id) err-not-found))
            (total-shares (get total-shares farm))
            (sold-shares (- total-shares (get available-shares farm)))
        )
        (asserts! (is-eq tx-sender (get owner farm)) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (> sold-shares u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set FarmRevenue farm-id { total-distributed: (+ (default-to u0 (get total-distributed (map-get? FarmRevenue farm-id)))
            amount
        ) }
        )
        (ok true)
    )
)

(define-public (claim-earnings (farm-id uint))
    (let (
            (farm (unwrap! (map-get? Farms farm-id) err-not-found))
            (shares (unwrap!
                (map-get? FarmShares {
                    farm-id: farm-id,
                    investor: tx-sender,
                })
                err-not-found
            ))
            (total-shares (get total-shares farm))
            (sold-shares (- total-shares (get available-shares farm)))
            (total-distributed (default-to u0 (get total-distributed (map-get? FarmRevenue farm-id))))
            (investor-share (* total-distributed (get shares shares)))
            (earnings-owed (/ investor-share sold-shares))
            (claimed-earnings (default-to u0
                (get earnings
                    (map-get? InvestorEarnings {
                        farm-id: farm-id,
                        investor: tx-sender,
                    })
                )))
            (unclaimed-earnings (- earnings-owed claimed-earnings))
        )
        (asserts! (> unclaimed-earnings u0) err-no-earnings)
        (try! (as-contract (stx-transfer? unclaimed-earnings tx-sender tx-sender)))
        (map-set InvestorEarnings {
            farm-id: farm-id,
            investor: tx-sender,
        } { earnings: earnings-owed }
        )
        (ok unclaimed-earnings)
    )
)

(define-public (stake-shares
        (farm-id uint)
        (share-count uint)
        (duration uint)
    )
    (let (
            (current-shares (unwrap!
                (map-get? FarmShares {
                    farm-id: farm-id,
                    investor: tx-sender,
                })
                err-not-found
            ))
            (existing-stake (map-get? StakedShares {
                farm-id: farm-id,
                investor: tx-sender,
            }))
            (multiplier (get-reward-multiplier duration))
        )
        (asserts! (is-none existing-stake) err-stake-active)
        (asserts! (>= (get shares current-shares) share-count)
            err-insufficient-shares
        )
        (asserts!
            (or
                (is-eq duration u30)
                (is-eq duration u90)
                (is-eq duration u180)
                (is-eq duration u365)
            )
            err-invalid-duration
        )
        (map-set StakedShares {
            farm-id: farm-id,
            investor: tx-sender,
        } {
            staked-amount: share-count,
            stake-start: stacks-block-height,
            stake-duration: duration,
            reward-multiplier: multiplier,
        })
        (ok true)
    )
)

(define-public (unstake-shares (farm-id uint))
    (let (
            (stake-info (unwrap!
                (map-get? StakedShares {
                    farm-id: farm-id,
                    investor: tx-sender,
                })
                err-not-found
            ))
            (blocks-staked (- stacks-block-height (get stake-start stake-info)))
            (required-blocks (* (get stake-duration stake-info) u144))
        )
        (asserts! (>= blocks-staked required-blocks) err-stake-locked)
        (map-delete StakedShares {
            farm-id: farm-id,
            investor: tx-sender,
        })
        (ok (get staked-amount stake-info))
    )
)

(define-public (claim-staking-rewards (farm-id uint))
    (let (
            (stake-info (unwrap!
                (map-get? StakedShares {
                    farm-id: farm-id,
                    investor: tx-sender,
                })
                err-not-found
            ))
            (blocks-staked (- stacks-block-height (get stake-start stake-info)))
            (required-blocks (* (get stake-duration stake-info) u144))
            (reward-amount (calculate-staking-reward farm-id tx-sender))
        )
        (asserts! (>= blocks-staked required-blocks) err-stake-locked)
        (asserts! (> reward-amount u0) err-no-earnings)
        (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
        (map-set StakingRewards {
            farm-id: farm-id,
            investor: tx-sender,
        } { total-rewards: (+
            (default-to u0
                (get total-rewards
                    (map-get? StakingRewards {
                        farm-id: farm-id,
                        investor: tx-sender,
                    })
                ))
            reward-amount
        ) }
        )
        (ok reward-amount)
    )
)

(define-private (get-reward-multiplier (duration uint))
    (if (is-eq duration u30)
        u110
        (if (is-eq duration u90)
            u125
            (if (is-eq duration u180)
                u150
                u200
            )
        )
    )
)

(define-private (calculate-staking-reward
        (farm-id uint)
        (investor principal)
    )
    (match (map-get? StakedShares {
        farm-id: farm-id,
        investor: investor,
    })
        stake-info (let (
                (base-reward (* (get staked-amount stake-info) u1000))
                (multiplier (get reward-multiplier stake-info))
                (blocks-staked (- stacks-block-height (get stake-start stake-info)))
                (reward-per-block (/ (* base-reward multiplier) u100))
            )
            (/ (* reward-per-block blocks-staked) u144)
        )
        u0
    )
)

;; ========================================
;; INSURANCE FEATURE FUNCTIONS
;; ========================================

(define-public (create-insurance-policy
        (farm-id uint)
        (policy-type (string-ascii 20))
        (coverage-amount uint)
        (duration-days uint)
    )
    (let (
            (farm (unwrap! (map-get? Farms farm-id) err-not-found))
            (policy-id (+ (var-get total-policies) u1))
            (premium (calculate-premium farm-id policy-type coverage-amount))
            (start-date stacks-block-height)
            (end-date (+ start-date (* duration-days u144)))
        )
        (asserts! (is-eq tx-sender (get owner farm)) err-unauthorized)
        (asserts! (> coverage-amount u0) err-invalid-amount)
        (asserts! (> duration-days u0) err-invalid-duration)
        (asserts! 
            (or 
                (is-eq policy-type "crop")
                (is-eq policy-type "equipment")
                (is-eq policy-type "weather")
            )
            err-invalid-amount
        )
        (map-set InsurancePolicies policy-id {
            policy-id: policy-id,
            farm-id: farm-id,
            owner: tx-sender,
            policy-type: policy-type,
            coverage-amount: coverage-amount,
            premium: premium,
            start-date: start-date,
            end-date: end-date,
            active: false,
        })
        (var-set total-policies policy-id)
        (ok policy-id)
    )
)

(define-public (purchase-insurance (policy-id uint))
    (let (
            (policy (unwrap! (map-get? InsurancePolicies policy-id) err-policy-not-found))
            (premium (get premium policy))
        )
        (asserts! (is-eq tx-sender (get owner policy)) err-unauthorized-claim)
        (asserts! (not (get active policy)) err-policy-inactive)
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (map-set InsurancePolicies policy-id (merge policy { active: true }))
        (map-set PolicyPremiumPool policy-id { 
            total-premiums: (+ premium 
                (default-to u0 (get total-premiums (map-get? PolicyPremiumPool policy-id)))
            ) 
        })
        (ok true)
    )
)

(define-public (file-claim
        (policy-id uint)
        (claim-amount uint)
        (claim-reason (string-ascii 200))
    )
    (let (
            (policy (unwrap! (map-get? InsurancePolicies policy-id) err-policy-not-found))
            (claim-id (+ (var-get total-claims) u1))
        )
        (asserts! (is-eq tx-sender (get owner policy)) err-unauthorized-claim)
        (asserts! (get active policy) err-policy-inactive)
        (asserts! (<= stacks-block-height (get end-date policy)) err-policy-expired)
        (asserts! (> claim-amount u0) err-invalid-claim-amount)
        (asserts! (<= claim-amount (get coverage-amount policy)) err-insufficient-coverage)
        (map-set InsuranceClaims claim-id {
            claim-id: claim-id,
            policy-id: policy-id,
            claimant: tx-sender,
            claim-amount: claim-amount,
            claim-reason: claim-reason,
            status: "pending",
            filed-date: stacks-block-height,
            processed-date: none,
        })
        (var-set total-claims claim-id)
        (ok claim-id)
    )
)

(define-public (validate-claim (claim-id uint) (approved bool))
    (let (
            (claim (unwrap! (map-get? InsuranceClaims claim-id) err-not-found))
            (policy (unwrap! (map-get? InsurancePolicies (get policy-id claim)) err-policy-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status claim) "pending") err-claim-already-filed)
        (if approved
            (begin
                (map-set InsuranceClaims claim-id (merge claim {
                    status: "approved",
                    processed-date: (some stacks-block-height),
                }))
                (try! (process-payout claim-id))
                (ok true)
            )
            (begin
                (map-set InsuranceClaims claim-id (merge claim {
                    status: "rejected",
                    processed-date: (some stacks-block-height),
                }))
                (ok false)
            )
        )
    )
)

(define-public (process-payout (claim-id uint))
    (let (
            (claim (unwrap! (map-get? InsuranceClaims claim-id) err-not-found))
            (claim-amount (get claim-amount claim))
            (claimant (get claimant claim))
        )
        (asserts! (is-eq (get status claim) "approved") err-unauthorized-claim)
        (try! (as-contract (stx-transfer? claim-amount tx-sender claimant)))
        (ok claim-amount)
    )
)

(define-public (cancel-policy (policy-id uint))
    (let (
            (policy (unwrap! (map-get? InsurancePolicies policy-id) err-policy-not-found))
            (premium (get premium policy))
            (refund-amount (/ premium u2))
        )
        (asserts! (is-eq tx-sender (get owner policy)) err-unauthorized-claim)
        (asserts! (get active policy) err-policy-inactive)
        (asserts! (<= stacks-block-height (get end-date policy)) err-policy-expired)
        (try! (as-contract (stx-transfer? refund-amount tx-sender (get owner policy))))
        (map-set InsurancePolicies policy-id (merge policy { active: false }))
        (ok refund-amount)
    )
)

(define-private (calculate-premium
        (farm-id uint)
        (policy-type (string-ascii 20))
        (coverage-amount uint)
    )
    (let (
            (farm (unwrap! (map-get? Farms farm-id) (err u0)))
            (location (get location farm))
            (farm-size (get size farm))
            (base-rate (get-policy-base-rate policy-type))
            (location-multiplier (default-to u100 (get risk-multiplier (map-get? RiskFactors location))))
            (size-multiplier (calculate-size-multiplier farm-size))
            (history-multiplier (get-claim-history-multiplier farm-id policy-type))
        )
        (let (
                (base-premium (/ (* coverage-amount base-rate) u10000))
                (location-adjusted (/ (* base-premium location-multiplier) u100))
                (size-adjusted (/ (* location-adjusted size-multiplier) u100))
                (final-premium (/ (* size-adjusted history-multiplier) u100))
            )
            final-premium
        )
    )
)

(define-private (get-policy-base-rate (policy-type (string-ascii 20)))
    (if (is-eq policy-type "crop")
        u500
        (if (is-eq policy-type "equipment")
            u300
            u800
        )
    )
)

(define-private (calculate-size-multiplier (farm-size uint))
    (if (<= farm-size u100)
        u120
        (if (<= farm-size u500)
            u100
            u85
        )
    )
)

(define-private (get-claim-history-multiplier (farm-id uint) (policy-type (string-ascii 20)))
    (let (
            (claim-count (default-to u0 
                (get claim-count (map-get? ClaimHistory {
                    farm-id: farm-id,
                    policy-type: policy-type,
                }))
            ))
        )
        (if (is-eq claim-count u0)
            u90
            (if (<= claim-count u2)
                u100
                (+ u100 (* (- claim-count u2) u25))
            )
        )
    )
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

;; Core farm tokenization read-only functions
(define-read-only (get-farm-details (farm-id uint))
    (map-get? Farms farm-id)
)

(define-read-only (get-investor-shares (farm-id uint) (investor principal))
    (map-get? FarmShares {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (get-investor-portfolio (investor principal))
    (map-get? InvestorPortfolio investor)
)

(define-read-only (get-total-farms)
    (var-get total-farms)
)

(define-read-only (get-farm-revenue (farm-id uint))
    (map-get? FarmRevenue farm-id)
)

(define-read-only (get-investor-earnings (farm-id uint) (investor principal))
    (map-get? InvestorEarnings {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (calculate-pending-earnings (farm-id uint) (investor principal))
    (match (map-get? Farms farm-id)
        farm (match (map-get? FarmShares {
            farm-id: farm-id,
            investor: investor,
        })
            shares (let (
                    (total-shares (get total-shares farm))
                    (sold-shares (- total-shares (get available-shares farm)))
                    (total-distributed (default-to u0
                        (get total-distributed (map-get? FarmRevenue farm-id))
                    ))
                    (investor-share (* total-distributed (get shares shares)))
                    (earnings-owed (if (> sold-shares u0)
                        (/ investor-share sold-shares)
                        u0
                    ))
                    (claimed-earnings (default-to u0
                        (get earnings
                            (map-get? InvestorEarnings {
                                farm-id: farm-id,
                                investor: investor,
                            })
                        )))
                )
                (some (- earnings-owed claimed-earnings))
            )
            none
        )
        none
    )
)

(define-read-only (get-stake-info (farm-id uint) (investor principal))
    (map-get? StakedShares {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (get-staking-rewards (farm-id uint) (investor principal))
    (map-get? StakingRewards {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (calculate-pending-staking-rewards (farm-id uint) (investor principal))
    (some (calculate-staking-reward farm-id investor))
)

;; Insurance read-only functions
(define-read-only (get-policy-details (policy-id uint))
    (map-get? InsurancePolicies policy-id)
)

(define-read-only (get-claim-status (claim-id uint))
    (map-get? InsuranceClaims claim-id)
)

(define-read-only (get-total-policies)
    (var-get total-policies)
)

(define-read-only (get-total-claims)
    (var-get total-claims)
)

(define-read-only (get-policy-premium-estimate 
        (farm-id uint) 
        (policy-type (string-ascii 20)) 
        (coverage-amount uint)
    )
    (some (calculate-premium farm-id policy-type coverage-amount))
)

(define-read-only (get-claim-history (farm-id uint) (policy-type (string-ascii 20)))
    (map-get? ClaimHistory {
        farm-id: farm-id,
        policy-type: policy-type,
    })
)

;; Contract initialization - set risk factors for different locations
(map-set RiskFactors "california" { risk-multiplier: u85 })
(map-set RiskFactors "texas" { risk-multiplier: u95 })
(map-set RiskFactors "iowa" { risk-multiplier: u75 })
(map-set RiskFactors "florida" { risk-multiplier: u125 })
(map-set RiskFactors "nebraska" { risk-multiplier: u80 })
(map-set RiskFactors "default" { risk-multiplier: u100 })
