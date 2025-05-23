
## LendLayer

###  Overview

**LendLayer** is a decentralized finance (DeFi) lending protocol built in [Clarity](https://docs.stacks.co/docs/clarity/clarity-introduction/), designed for the Stacks blockchain. It enables users to **deposit STX tokens**, **earn interest**, **borrow against collateral**, and **participate in liquidation events** while maintaining a capital-efficient and fair ecosystem.

---

### 🚀 Features

* 📥 **Deposits**: Earn passive income by depositing STX.
* 💸 **Borrowing**: Take loans against STX collateral based on a defined collateral ratio.
* 🏦 **Interest Accrual**: Dynamic interest rate calculation based on pool utilization.
* 🧮 **Epoch-Based Time**: Interest and rewards are calculated per epoch.
* 🛡️ **Collateral Management**: Secure your borrow position by depositing and withdrawing STX as collateral.
* ⚠️ **Liquidation Mechanics**: Liquidate undercollateralized positions for a bonus.
* 🧠 **Admin Control**: Update interest and rates by admin only.
* 📊 **Utilization-Driven APR**: Interest rates adjust based on lending pool usage.

---

### 🏗️ Contract Architecture

#### 🔐 Admin Functions

* `update-interest`: Increment the epoch and accumulate interest.
* `update-interest-rate`: Dynamically recalculates and updates the pool's interest rate.

#### 💰 Lending & Borrowing

* `deposit(amount)`: Deposit STX into the pool and start earning interest.
* `borrow(amount)`: Borrow STX if sufficient collateral is provided.
* `repay(amount)`: Repay borrowed STX along with calculated interest.

#### 🏦 Collateral Management

* `deposit-collateral(amount)`: Lock STX as collateral for future borrowing.
* `withdraw-collateral(amount)`: Withdraw unlocked collateral if sufficient buffer exists.

#### 🔨 Liquidation

* `liquidate(target)`: Trigger liquidation on a position below the collateral threshold and receive a bonus.

#### 📈 Interest & Risk Analysis

* `calculate-interest-rate`: Read-only function to calculate interest based on pool utilization.
* `get-utilization-rate`: Returns how much of the pool is currently borrowed.
* `get-user-borrow(user)`: View outstanding borrow balance + accrued interest.
* `get-claimable-interest(user)`: View claimable interest for any lender.
* `claim-interest`: Transfer claimable interest to the user.
* `get-liquidation-risk(user)`: Assess the health and risk of a borrower's position.

---

### ⚙️ Key Constants

| Constant                | Value                | Description                        |
| ----------------------- | -------------------- | ---------------------------------- |
| `MAX_DEPOSIT`           | `1_000_000_000_000`  | Maximum per-user deposit           |
| `MAX_POOL_SIZE`         | `10_000_000_000_000` | Total pool cap                     |
| `MIN_COLLATERAL`        | `1_000_000`          | Minimum collateral required        |
| `COLLATERAL_RATIO`      | `15000` (150%)       | Borrowing collateral ratio         |
| `LIQUIDATION_THRESHOLD` | `13000` (130%)       | Below this, loans are liquidatable |
| `LIQUIDATION_BONUS`     | `500` (5%)           | Bonus for liquidators              |

---

### 🔐 Errors

| Error Code | Description                 |
| ---------- | --------------------------- |
| `u1`       | Not authorized (admin-only) |
| `u2`       | Insufficient balance        |
| `u3`       | Insufficient collateral     |
| `u4`       | Pool is empty               |
| `u5`       | Invalid amount              |
| `u6`       | Deposit limit reached       |
| `u7`       | Pool size exceeded          |
| `u8`       | Below minimum collateral    |
| `u9`       | Active loan exists          |
| `u10`      | Not liquidatable            |
| `u11`      | Already liquidated          |

---

### 📦 Installation & Deployment

1. Deploy this Clarity smart contract using [Clarity CLI](https://docs.stacks.co/docs/clarity/using-clarity-cli/) or [Stacks Explorer](https://explorer.stacks.co/).
2. Use a frontend interface or directly interact via the contract’s functions using Clarity-enabled wallets like [Hiro Wallet](https://www.hiro.so/wallet).
3. Admin key will be `tx-sender` upon deployment — manage updates accordingly.

---

### 🧪 Testing

Run tests using:

```bash
clarinet test
```

Ensure:

* Deposits and borrows execute under valid constraints.
* Collateral and liquidation logic behave as expected.
* Interest accrual over epochs is correct.
* Only admin can update interest rates.

---

### 🔮 Future Improvements

* Multi-asset lending support (e.g., using SIP-010 tokens)
* Frontend dashboard for easier UX
* Flash loans
* Staking rewards

---
