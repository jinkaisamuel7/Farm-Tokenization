(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-unauthorized (err u103))

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
