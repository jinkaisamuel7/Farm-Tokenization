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

(define-data-var total-farms uint u0)

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

(define-read-only (get-farm-details (farm-id uint))
    (map-get? Farms farm-id)
)

(define-read-only (get-investor-shares
        (farm-id uint)
        (investor principal)
    )
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

(define-read-only (get-farm-revenue (farm-id uint))
    (map-get? FarmRevenue farm-id)
)

(define-read-only (get-investor-earnings
        (farm-id uint)
        (investor principal)
    )
    (map-get? InvestorEarnings {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (calculate-pending-earnings
        (farm-id uint)
        (investor principal)
    )
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

(define-read-only (get-stake-info
        (farm-id uint)
        (investor principal)
    )
    (map-get? StakedShares {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (get-staking-rewards
        (farm-id uint)
        (investor principal)
    )
    (map-get? StakingRewards {
        farm-id: farm-id,
        investor: investor,
    })
)

(define-read-only (calculate-pending-staking-rewards
        (farm-id uint)
        (investor principal)
    )
    (some (calculate-staking-reward farm-id investor))
)
