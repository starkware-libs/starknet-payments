Contract
Structs
Order
HashType
Signature
Errors
Events
FeeSet
FeeRecipientSet
TokenRegistered
TokenRemoved
AddressAllowed
AddressDisallowed
TradeExecuted
OrderCanceled
Constructor
Description
Validations
Logic
Components
Pausable
Replaceability
Roles
Public methods
Trade
Description
Access Control
Validations
Logic
SetDustLimit
Description
Access Control
Validations
Logic
SetFee
Description
Access Control
Validations
Logic


SetFeeRecipient
Description
Access Control
Validations
Logic
CancelOrder
Description
Access Control
Validations
Logic
GetOrderFulfillment
Description
Access Control
Validations
Logic
RegisterToken
Description
Access Control
Validations
Logic
RemoveToken
Description
Access Control
Validations
Logic
IsTokenRegistered
Description
Access Control
Validations
Logic
AddToAllowlist
Description
Access Control
Validations
Logic
RemoveFromAllowlist
Description
Access Control
Validations
Logic
IsAllowed


```
Description
Access Control
Validations
Logic
GetDustLimit
Description
Access Control
Validations
Logic
GetFeeLimit
Description
Access Control
Validations
Logic
GetFee
Description
Access Control
Validations
Logic
GetFeeRecipient
Description
Access Control
Validations
Logic
```
# Madu Payment - Specs.

## Table of contents

Contract
Structs
Errors
Events
Constructor
Description
Validations
Logic
Components
Pausable
Replaceability


Roles
Public methods
Trade
Description
Access Control
Validations
Logic
SetFeeLimit
Description
Access Control
Validations
Logic
SetFee
Description
Access Control
Validations
Logic
SetFeeRecipient
Description
Access Control
Validations
Logic
SetFee
Description
Access Control
Validations
Logic
CancelOrder
Description
Access Control
Validations
Logic
IsOrderFulfilled
Description
Access Control
Validations
Logic
RegisterToken
Description
Access Control
Validations


```
Rust
None
Logic
RemoveToken
Description
Access Control
Validations
Logic
IsTokenRegistered
Description
Access Control
Validations
Logic
```
## Contract

### Structs

#### Order

```
pub struct Order {
pub salt: felt252,
pub expiry: Timestamp,
pub user: ContractAddress,
pub sell_token: ContractAddress,
pub buy_token: ContractAddress,
pub sell_amount: u128,
pub buy_amount: u128,
pub allowed_addresses: Span<ContractAddress>,
}
```
#### HashType

```
pub type HashType = felt252;
```

```
None
```
#### Signature

```
pub type Signature = Span<felt252>;
```
### Errors

##### - ADDRESS_ALREADY_ALLOWED

##### - INVALID_AMOUNT_RATIO

##### - INVALID_AMOUNT_TOO_LARGE

##### - INVALID_DOWNCAST_AFTER_DIVISION

##### - INVALID_HIGH_FEE

##### - INVALID_HIGH_FEE_LIMIT

##### - INVALID_STARK_SIGNATURE

##### - INVALID_TOKEN_PAIR

##### - INVALID_TRADE_SAME_USER

##### - INVALID_ZERO_ADDRESS

##### - INVALID_ZERO_AMOUNT

##### - INVALID_ZERO_TOKEN

##### - ORDER_EXPIRED

##### - TOKEN_ALREADY_REGISTERED

##### - TOKEN_NOT_REGISTERED

##### - UNALLOWED_ADDRESS

##### - UNAPPROVED_COUNTERPARTY

##### - TRANSFER_FAILED

### Events

#### FeeSet

Data Type Keyed
fee u128 no

#### FeeRecipientSet

Data Type Keyed
old_recipient ContractAddress yes
new_recipient ContractAddress yes


#### TokenRegistered

Data Type Keyed
token ContractAddress yes

#### TokenRemoved

Data Type Keyed
token ContractAddress yes

#### AddressAllowed

Data Type Keyed
address ContractAddress yes

#### AddressDisallowed

Data Type Keyed
address ContractAddress yes

#### TradeExecuted

Data Type Keyed
user_a ContractAddress yes
user_b ContractAddress yes
sell_token ContractAddress yes
buy_token ContractAddress yes
order_a_sell_amount u128 no
order_a_buy_amount u128 no
fee_a u128 no
fee_b u128 no


```
None
```
#### OrderCanceled

Data Type Keyed
user ContractAddress yes
hash TypeHash yes

### Constructor

#### Description

#### It only runs once when deploying the contract and is used to initialize the state of the

#### contract.

```
fn constructor(
ref self: ContractState,
governance_admin: ContractAddress,
upgrade_delay: u64,
fee_limit: u128,
fee_recipient: ContractAddress,
fee: u128,
)
```
#### Validations

1. Fee recipient is not zero.
2. Fee_limit <= MAX_BASIS_POINTS.
3. Fee <= fee_limit.

#### Logic

1. Initialize roles with the governance_admin address.
2. Update replaceability upgrade delay.
3. Set fee_limit, fee_recipient and fee.


```
None
None
None
```
### Components

#### Pausable

In charge of the pause mechanism of the contract.
#[starknet::interface]
pub trait IPausable<TState> {
fn is_paused(self: @TState) -> bool;
fn pause(ref self: TState);
fn unpause(ref self: TState);
}
#[storage]
pub struct Storage {
pub paused: bool,
}

#### Replaceability

In charge of the upgrades of the contract
#[starknet::interface]
pub trait IReplaceable<TContractState> {
fn get_upgrade_delay(self: @TContractState) -> u64;
fn get_impl_activation_time(
self: @TContractState, implementation_data: ImplementationData,
) -> u64;
fn add_new_implementation(ref self: TContractState, implementation_data:
ImplementationData);
fn remove_implementation(ref self: TContractState, implementation_data:
ImplementationData);
fn replace_to(ref self: TContractState, implementation_data:
ImplementationData);
}


```
None
None
#[storage]
struct Storage {
// Delay in seconds before performing an upgrade.
upgrade_delay: u64,
// Timestamp by which implementation can be activated.
impl_activation_time: Map<felt252, u64>,
// Timestamp until which implementation can be activated.
impl_expiration_time: Map<felt252, u64>,
// Is the implementation finalized.
finalized: bool,
}
```
#### Roles

In charge of access control in the contract.
#[starknet::interface]
pub trait IRoles<TContractState> {
fn is_app_governor(self: @TContractState, account: ContractAddress) ->
bool;
fn is_app_role_admin(self: @TContractState, account: ContractAddress) ->
bool;
fn is_governance_admin(self: @TContractState, account: ContractAddress) ->
bool;
fn is_operator(self: @TContractState, account: ContractAddress) -> bool;
fn is_token_admin(self: @TContractState, account: ContractAddress) -> bool;
fn is_upgrade_governor(self: @TContractState, account: ContractAddress) ->
bool;
fn is_security_admin(self: @TContractState, account: ContractAddress) ->
bool;
fn is_security_agent(self: @TContractState, account: ContractAddress) ->
bool;
fn register_app_governor(ref self: TContractState, account:
ContractAddress);


```
None
fn remove_app_governor(ref self: TContractState, account: ContractAddress);
fn register_app_role_admin(ref self: TContractState, account:
ContractAddress);
fn remove_app_role_admin(ref self: TContractState, account:
ContractAddress);
fn register_governance_admin(ref self: TContractState, account:
ContractAddress);
fn remove_governance_admin(ref self: TContractState, account:
ContractAddress);
fn register_operator(ref self: TContractState, account: ContractAddress);
fn remove_operator(ref self: TContractState, account: ContractAddress);
fn register_token_admin(ref self: TContractState, account:
ContractAddress);
fn remove_token_admin(ref self: TContractState, account: ContractAddress);
fn register_upgrade_governor(ref self: TContractState, account:
ContractAddress);
fn remove_upgrade_governor(ref self: TContractState, account:
ContractAddress);
fn renounce(ref self: TContractState, role: RoleId);
fn register_security_admin(ref self: TContractState, account:
ContractAddress);
fn remove_security_admin(ref self: TContractState, account:
ContractAddress);
fn register_security_agent(ref self: TContractState, account:
ContractAddress);
fn remove_security_agent(ref self: TContractState, account:
ContractAddress);
}
```
### Public methods

#### Trade

Description
fn trade(
self: @ContractState,
order_a: Order,


order_b: Order,
signature_a: Span<felt252>,
signature_b: Span<felt252>,
order_a_actual_sell_amount: u128,
order_a_actual_buy_amount: u128,
);
Access Control
Anyone can execute.
Validations

1. Pausable check.
2. Signature check.
3. Expiration check.
4. order_X.user is allowed address.
5. order_a.user != order_b.user.
6. order_X.sell_amount != 0.
7. order_X.buy_amount != 0.
8. Order_a_actual_sell_amount and Order_a_actual_buy_amount are non-zero.
9. order_X.sell_token != order_X.buy_token, and are registered tokens.
10. Check order_a.user is among the buyer_order.allowed_addresses.
11. Check buyer_order.user is among the seller_order.allowed_addresses.
12. order_a.sell_token == order_b.buy_token
13. order_a.buy_token == order_b.sell_token
14. order_a.sell_amount >= actual_sell_amount.
15. order_a.buy_amount >= actual_buy_amount.
16. order_b.sell_amount >= order_a_actual_buy_amount.
17. order_b.buy_amount >= order_a_actual_sell_amount.
18. order_a.sell_amount / order_a_actual_sell_amount ≤ order_a.buy_amount /
    order_a_actual_buy_amount
19. order_b.sell_amount / order_a_actual_buy_amount ≤ order_b.buy_amount /
    order_a_actual_sell_amount
20. Fulfillment[order_hash_a]+ order_a_actual_sell_amount≤order_a.sell_amount
21. Fulfillment[order_hash_b]+ order_a_actual_buy_amount≤order_b.sell_amount


None
None
Logic

1. Run Validations.
2. Transfer fee from order_X.sell_token.
3. Transfer money from both tokens.
4. fulfillment[order_hash_a]+=|order_a_actual_sell_amount|
5. fulfillment[order_hash_b]+=|order_a_actual_buy_amount|
6. Emit TradeExecuted event.

#### SetDustLimit

Description
fn set_dust_limit(self: @ContractState, dust_limit: u128);
Access Control
Only the operator can execute.
Validations

1. dust_limit is non zero.
Logic
1. Run Validations.
2. update dust_limit.
3. Emit DustLimitSet event.

#### SetFee

Description
fn set_fee(self: @ContractState, fee: u128);


None
Access Control
Only the operator can execute.
Validations

2. fee <= fee_limit.
Logic
4. Run Validations.
5. update fee.
6. Emit SetFee event.

#### SetFeeRecipient

Description
fn set_fee_recipient(
self: @ContractState,
fee_recipient: ContractAddress
);
Access Control
Only the operator can execute.
Validations

1. fee_recipient.is_non_zero()
Logic
1. Run Validations.
2. Update fee recipient.
3. Emit FeeRecipientSet event.


```
None
None
```
#### CancelOrder

Description
Operator cancels partially fulfilled orders.
fn cancel_orders(
self: @ContractState,
orders: Span<Order>,
);
Access Control
Only the operator can execute.
Validations
Logic

1. Calculate order hash.
2. Update fulfillment to order.sell_amount (which would prevent trading the order).
3. Emit OrderCanceled event.

#### GetOrderFulfillment

Description
fn get_order_fulfillment(
self: @ContractState,
order_hash: HashType,
);


None
Access Control
Anyone can execute.
Validations
Logic

1. Return fulfillment value of order_hash.

#### RegisterToken

Description
fn register_token(
ref self: ContractState,
token: ContractAddress,
);
Access Control
Only the app Governor can execute.
Validations

1. Token was not registered yet.
2. Token is non zero.
Logic
2. Run Validations.
3. Add token to the token map.
4. Emit TokenRegistered event.


```
None
None
```
#### RemoveToken

Description
fn remove_token(
ref self: ContractState,
token: ContractAddress,
);
Access Control
Only the app Governor can execute.
Validations

1. Token was registered.
Logic
1. Run Validations.
2. Remove token from the token map.
3. Emit TokenRemoved event.

#### IsTokenRegistered

Description
fn is_token_registered(
self: @ContractState,
token: ContractAddress,
);
Access Control
Anyone can execute.


None
Validations

1. Check token is non-zero.
Logic
1. Run validations.
2. Check token map.

#### AddToAllowlist

Description
fn add_to_allowlist(
ref self: ContractState,
address: ContractAddress,
);
Access Control
Only the app Governor can execute.
Validations

3. address was not added yet.
4. address is non zero.
Logic
5. Run Validations.
6. Add address to the allowlist map.
7. Emit AddressAllowed event.

#### RemoveFromAllowlist

Description


None
None
fn remove_from_allowlist(
ref self: ContractState,
address: ContractAddress,
);
Access Control
Only the app Governor can execute.
Validations

2. address was registered.
Logic
4. Run Validations.
5. Remove address from the allowlist map.
6. Emit AddressDisallowed event.

#### IsAllowed

Description
fn is_allowed(
self: @ContractState,
address: ContractAddress,
);
Access Control
Anyone can execute.
Validations

1. Check token is non-zero.


None
None
Logic

1. Run validations.
2. Check allowlist map.

#### GetDustLimit

Description
fn get_dust_limit(self: @ContractState) -> u128;
Access Control
Anyone can execute.
Validations
Logic

1. Read dust_limit.

#### GetFeeLimit

Description
fn get_fee_limit(self: @ContractState) -> u128;
Access Control
Anyone can execute.
Validations
Logic

1. Read fee_limit.


```
None
None
```
#### GetFee

Description
fn get_fee(self: @ContractState) -> u128;
Access Control
Anyone can execute.
Validations
Logic

1. Read fee.

#### GetFeeRecipient

Description
fn get_fee_recipient(self: @ContractState) -> ContractAddress;
Access Control
Anyone can execute.
Validations
Logic

1. Read fee recipient.


