;; LendLayer - DeFi Lending Platform

;; Constants & Errors
(define-constant MAX_DEPOSIT u1000000000000)
(define-constant MAX_POOL_SIZE u10000000000000)
(define-constant MIN_COLLATERAL u1000000)
(define-constant LIQUIDATION_THRESHOLD u13000)
(define-constant LIQUIDATION_BONUS u500)

;; traits
;;
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u3))
(define-constant ERR-POOL-EMPTY (err u4))
(define-constant ERR-INVALID-AMOUNT (err u5))
(define-constant ERR-DEPOSIT-LIMIT (err u6))
(define-constant ERR-POOL-LIMIT (err u7))
(define-constant ERR-MIN-COLLATERAL (err u8))
(define-constant ERR-ACTIVE-LOAN (err u9))
(define-constant ERR-NOT-LIQUIDATABLE (err u10))
(define-constant ERR-ALREADY-LIQUIDATED (err u11))

;; token definitions
;;
;; Variables
(define-data-var total-liquidity uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var base-rate uint u500)
(define-data-var slope1 uint u1000) 
(define-data-var slope2 uint u3000) 
(define-data-var optimal-utilization uint u8000)
(define-data-var collateral-ratio uint u15000)
(define-data-var admin principal tx-sender)
(define-data-var current-epoch uint u0)
(define-data-var interest-accumulated uint u0)
(define-data-var interest-rate uint u500)

;; constants
;;
;; Maps
(define-map deposits principal uint)
(define-map borrows principal uint)
(define-map collateral principal uint)
(define-map last-epoch principal uint)
(define-map last-interest-claim principal uint)
(define-map claimed-interest principal uint)

;; data vars
;;
;; Admin Functions
(define-public (update-interest)
    (let ((sender tx-sender))
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (var-set current-epoch (+ (var-get current-epoch) u1))
        (var-set interest-accumulated (+ (var-get interest-accumulated) (var-get interest-rate)))
        (ok true)))

;; data maps
;;
;; Core Functions
(define-public (deposit (amount uint))
    (let (
        (sender tx-sender)
        (current-deposit (default-to u0 (map-get? deposits sender)))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ current-deposit amount) MAX_DEPOSIT) ERR-DEPOSIT-LIMIT)
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set deposits sender (+ current-deposit amount))
    (map-set last-interest-claim sender (var-get current-epoch))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok amount)))

;; public functions
;;
(define-public (borrow (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? collateral sender)))
        (required-collateral (/ (* amount (var-get collateral-ratio)) u10000))
    )
    (asserts! (>= current-collateral required-collateral) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! (<= amount (var-get total-liquidity)) ERR-POOL-EMPTY)
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set borrows sender (+ (default-to u0 (map-get? borrows sender)) amount))
    (map-set last-epoch sender (var-get current-epoch))
    (var-set total-borrowed (+ (var-get total-borrowed) amount))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (try! (update-interest-rate))
    (ok amount)))

(define-public (repay (amount uint))
(let (
    (sender tx-sender)
    (current-borrow (default-to u0 (map-get? borrows sender)))
    (borrow-epoch (default-to u0 (map-get? last-epoch sender)))
    (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
    (interest-owed (/ (* amount (* epochs-elapsed (var-get interest-rate))) u10000))
)
(asserts! (<= amount current-borrow) ERR-INVALID-AMOUNT)
(try! (stx-transfer? (+ amount interest-owed) sender (as-contract tx-sender)))
(map-set borrows sender (- current-borrow amount))
(var-set total-liquidity (+ (var-get total-liquidity) amount))
(ok amount)))

;; read only functions
;; Interest Rate Functions
(define-read-only (get-utilization-rate)
    (let (
        (liquidity (var-get total-liquidity))
    )
    (if (is-eq liquidity u0)
        u0
        (/ (* (var-get total-borrowed) u10000) liquidity))))

(define-read-only (calculate-interest-rate)
    (let (
        (utilization (get-utilization-rate))
        (optimal-util (var-get optimal-utilization))
    )
    (if (<= utilization optimal-util)
        ;; Below optimal: base-rate + slope1 * utilization
        (+ (var-get base-rate) 
           (/ (* utilization (var-get slope1)) u10000))
        ;; Above optimal: base-rate + slope1 * optimal + slope2 * (utilization - optimal)
        (+ (+ (var-get base-rate)
              (/ (* optimal-util (var-get slope1)) u10000))
           (/ (* (- utilization optimal-util) (var-get slope2)) u10000)))))


(define-read-only (get-user-deposit (user principal))
    (ok (default-to u0 (map-get? deposits user))))

(define-read-only (get-user-borrow (user principal))
    (let (
        (borrow-amount (default-to u0 (map-get? borrows user)))
        (borrow-epoch (default-to u0 (map-get? last-epoch user)))
        (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
        (interest-amount (/ (* borrow-amount (* epochs-elapsed (var-get interest-rate))) u10000))
    )
    (ok {
        borrow-amount: borrow-amount,
        interest-owed: interest-amount,
        total-owed: (+ borrow-amount interest-amount)
    })))

(define-read-only (get-claimable-interest (user principal))
    (let (
        (deposit-amount (default-to u0 (map-get? deposits user)))
        (last-claim (default-to u0 (map-get? last-interest-claim user)))
        (epochs-elapsed (- (var-get current-epoch) last-claim))
        (utilization-rate (get-utilization-rate))
        (interest-share (/ (* deposit-amount utilization-rate) u10000))
        (total-interest (* interest-share epochs-elapsed))
    )
    (ok {
        claimable-amount: total-interest,
        last-claim-epoch: last-claim,
        epochs-elapsed: epochs-elapsed
    })))


;; private functions
;; Collateral Functions
(define-public (deposit-collateral (amount uint))
    (let ((sender tx-sender))
        (asserts! (>= amount MIN_COLLATERAL) ERR-MIN-COLLATERAL)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set collateral 
            sender 
            (+ (default-to u0 (map-get? collateral sender)) amount))
        (ok amount)))

(define-public (withdraw-collateral (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? collateral sender)))
        (current-borrow (default-to u0 (map-get? borrows sender)))
        (required-collateral (/ (* current-borrow (var-get collateral-ratio)) u10000))
    )
    (asserts! (<= amount current-collateral) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! 
        (or 
            (is-eq current-borrow u0)
            (>= (- current-collateral amount) required-collateral)
        )
        ERR-ACTIVE-LOAN
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set collateral sender (- current-collateral amount))
    (ok amount)))

;; Liquidation Function
(define-public (liquidate (target principal))
    (let (
        (liquidator tx-sender)
        (target-collateral (default-to u0 (map-get? collateral target)))
        (target-borrow (default-to u0 (map-get? borrows target)))
        (current-ratio (/ (* target-collateral u10000) target-borrow))
        (bonus-amount (/ (* target-collateral LIQUIDATION_BONUS) u10000))
        (liquidation-amount (+ target-collateral bonus-amount))
    )
    (asserts! (< current-ratio LIQUIDATION_THRESHOLD) ERR-NOT-LIQUIDATABLE)
    (asserts! (> target-borrow u0) ERR-ALREADY-LIQUIDATED)

    (try! (stx-transfer? target-borrow liquidator (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? liquidation-amount (as-contract tx-sender) liquidator)))

    (map-set borrows target u0)
    (map-set collateral target u0)
    (map-set last-epoch target u0)

    (ok true)))

(define-public (update-interest-rate)
    (let (
        (sender tx-sender)
        (new-rate (calculate-interest-rate))
    )
    (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set interest-rate new-rate)
    (ok new-rate)))

(define-public (claim-interest)
    (let (
        (sender tx-sender)
        (claimable-info (unwrap-panic (get-claimable-interest sender)))
        (claim-amount (get claimable-amount claimable-info))
    )
    (asserts! (> claim-amount u0) ERR-INVALID-AMOUNT)
    (try! (as-contract (stx-transfer? claim-amount (as-contract tx-sender) sender)))
    (map-set last-interest-claim sender (var-get current-epoch))
    (map-set claimed-interest 
        sender 
        (+ (default-to u0 (map-get? claimed-interest sender)) claim-amount))
    (ok claim-amount)))

(define-read-only (get-pool-details)
    (ok {
        total-liquidity: (var-get total-liquidity),
        interest-rate: (var-get interest-rate),
        collateral-ratio: (var-get collateral-ratio),
        current-epoch: (var-get current-epoch),
        interest-accumulated: (var-get interest-accumulated)
    }))

(define-read-only (get-liquidation-risk (user principal))
    (let (
        (user-collateral (default-to u0 (map-get? collateral user)))
        (borrow-info (unwrap-panic (get-user-borrow user)))
        (total-owed (get total-owed borrow-info))
        (current-ratio (if (is-eq total-owed u0)
            u0
            (/ (* user-collateral u10000) total-owed)))
    )
    (ok {
        collateral-amount: user-collateral,
        current-ratio: current-ratio,
        liquidation-threshold: LIQUIDATION_THRESHOLD,
        at-risk: (< current-ratio LIQUIDATION_THRESHOLD),
        safety-buffer: (- current-ratio LIQUIDATION_THRESHOLD)
    })))
