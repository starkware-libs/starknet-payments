Madu Payment - Specs.
<br/>Table of contents

[Contract](#_hi8p87ta4dih)

[Structs](#_dqylky7t1zre)

[Errors](#_i8hni6o236jh)

[Events](#_6d7wqxod1a93)

[Constructor](#_clu7l3tu3q60)

[Description](#_faxdbk9kzlr)

[Validations](#_lm4rki7k4imd)

[Logic](#_md005wb16u11)

[Components](#_w9tlc0kx4coo)

[Pausable](#_73w9e2k16m4c)

[Replaceability](#_mo68luhqs3p8)

[Roles](#_rmlh8pr5ud09)

[Public methods](#_esiqura2wpub)

[Trade](#_z1cync14i1ps)

[Description](#_bcapkea6933d)

[Access Control](#_uh33ej26g1ix)

[Validations](#_ew5mwan6eslz)

[Logic](#_qnicbs2z31sx)

[SetFeeLimit](#_elaevzttlv5o)

[Description](#_nydgqi69b6i9)

[Access Control](#_po0kpdro8fjp)

[Validations](#_l4m8zzve1obf)

[Logic](#_lx8hzhutnupw)

[SetFee](#_yw08t3lctku4)

[Description](#_3qzvodlbiy1s)

[Access Control](#_7hbmbcqqrl8s)

[Validations](#_25m5y69j5x2j)

[Logic](#_82hkphpr8m3)

[SetFeeRecipient](#_1ayri8xsv9a7)

[Description](#_d4jnb4tw6ae0)

[Access Control](#_r6segeay1dfc)

[Validations](#_5z666auef4kc)

[Logic](#_i2rpcmnp08sx)

[SetFee](#_o3m6a46hep46)

[Description](#_j7azqltp2ng6)

[Access Control](#_eglxjfwfkkhj)

[Validations](#_62w7nyrrwkbu)

[Logic](#_anx4ujcr37en)

[CancelOrder](#_x5cj06orf8d3)

[Description](#_g34vnv1f7dpz)

[Access Control](#_29lwjxhbsuxm)

[Validations](#_15bklcsfaxxg)

[Logic](#_6sqvm9mrujz9)

[IsOrderFulfilled](#_6kctzg2pgubv)

[Description](#_yu30yq957j4)

[Access Control](#_3ctymfcmazey)

[Validations](#_pbj4pdp5m4sw)

[Logic](#_dyvwg2vj6egr)

[RegisterToken](#_1nuatdg1oqtw)

[Description](#_5o58voflz7fv)

[Access Control](#_u7e86d814afk)

[Validations](#_l6gl5oo6krbj)

[Logic](#_azn4t96amydo)

[RemoveToken](#_ssjc33n5dha9)

[Description](#_k8nx5pasorie)

[Access Control](#_nnpudvcqcha8)

[Validations](#_ahr6cf7mxvkr)

[Logic](#_a2r2vlqbbw1q)

[IsTokenRegistered](#_ywkhl4mipj2p)

[Description](#_rrwb5k8fj30m)

[Access Control](#_ecgbcqqfmm5x)

[Validations](#_il43w5hjnndh)

[Logic](#_x2iozgfdulda)

# Contract

### Structs

#### Order

pub struct Order {

pub salt: felt252,

pub expiry: Timestamp,

pub user: ContractAddress,

pub sell_token: ContractAddress,

pub buy_token: ContractAddress,

pub sell_amount: u128,

pub buy_amount: u128,

pub allowed_addresses: Span&lt;ContractAddress&gt;,

}



#### HashType

pub type HashType = felt252;



#### Signature

pub type Signature = Span&lt;felt252&gt;;



### Errors

- ADDRESS_ALREADY_ALLOWED
- INVALID_AMOUNT_RATIO
- INVALID_AMOUNT_TOO_LARGE
- INVALID_DOWNCAST_AFTER_DIVISION
- INVALID_HIGH_FEE
- INVALID_HIGH_FEE_LIMIT
- INVALID_STARK_SIGNATURE
- INVALID_TOKEN_PAIR
- INVALID_TRADE_SAME_USER
- INVALID_ZERO_ADDRESS
- INVALID_ZERO_AMOUNT
- INVALID_ZERO_TOKEN
- ORDER_EXPIRED
- TOKEN_ALREADY_REGISTERED
- TOKEN_NOT_REGISTERED
- UNALLOWED_ADDRESS
- UNAPPROVED_COUNTERPARTY
- TRANSFER_FAILED

### Events

#### FeeSet

| Data | Type | Keyed |
| --- | --- | --- |
| fee | u128 | no  |
| --- | --- | --- |

#### FeeRecipientSet

| Data | Type | Keyed |
| --- | --- | --- |
| old_recipient | ContractAddress | yes |
| --- | --- | --- |
| new_recipient | ContractAddress | yes |
| --- | --- | --- |

#### TokenRegistered

| Data | Type | Keyed |
| --- | --- | --- |
| token | ContractAddress | yes |
| --- | --- | --- |

#### TokenRemoved

| Data | Type | Keyed |
| --- | --- | --- |
| token | ContractAddress | yes |
| --- | --- | --- |

#### AddressAllowed

| Data | Type | Keyed |
| --- | --- | --- |
| address | ContractAddress | yes |
| --- | --- | --- |

#### AddressDisallowed

| Data | Type | Keyed |
| --- | --- | --- |
| address | ContractAddress | yes |
| --- | --- | --- |

#### TradeExecuted

| Data | Type | Keyed |
| --- | --- | --- |
| user_a | ContractAddress | yes |
| --- | --- | --- |
| user_b | ContractAddress | yes |
| --- | --- | --- |
| sell_token | ContractAddress | yes |
| --- | --- | --- |
| buy_token | ContractAddress | yes |
| --- | --- | --- |
| order_a_sell_amount | u128 | no  |
| --- | --- | --- |
| order_a_buy_amount | u128 | no  |
| --- | --- | --- |
| fee_a | u128 | no  |
| --- | --- | --- |
| fee_b | u128 | no  |
| --- | --- | --- |

####

#### OrderCanceled

| Data | Type | Keyed |
| --- | --- | --- |
| user | ContractAddress | yes |
| --- | --- | --- |
| hash | TypeHash | yes |
| --- | --- | --- |

####

### Constructor

#### Description

It only runs once when deploying the contract and is used to initialize the state of the contract.

fn constructor(

ref self: ContractState,

governance_admin: ContractAddress,

upgrade_delay: u64,

fee_limit: u128,

fee_recipient: ContractAddress,

fee: u128,

)



#### Validations

- Fee recipient is not zero.
- Fee_limit <= MAX_BASIS_POINTS.
- Fee <= fee_limit.

#### Logic

- Initialize roles with the governance_admin address.
- Update replaceability upgrade delay.
- Set fee_limit, fee_recipient and fee.

### Components

#### Pausable

In charge of the pause mechanism of the contract.

#\[starknet::interface\]

pub trait IPausable&lt;TState&gt; {

fn is_paused(self: @TState) -> bool;

fn pause(ref self: TState);

fn unpause(ref self: TState);

}



#\[storage\]

pub struct Storage {

pub paused: bool,

}



#### Replaceability

In charge of the upgrades of the contract

#\[starknet::interface\]

pub trait IReplaceable&lt;TContractState&gt; {

fn get_upgrade_delay(self: @TContractState) -> u64;

fn get_impl_activation_time(

self: @TContractState, implementation_data: ImplementationData,

) -> u64;

fn add_new_implementation(ref self: TContractState, implementation_data: ImplementationData);

fn remove_implementation(ref self: TContractState, implementation_data: ImplementationData);

fn replace_to(ref self: TContractState, implementation_data: ImplementationData);

}



#\[storage\]

struct Storage {

// Delay in seconds before performing an upgrade.

upgrade_delay: u64,

// Timestamp by which implementation can be activated.

impl_activation_time: Map&lt;felt252, u64&gt;,

// Timestamp until which implementation can be activated.

impl_expiration_time: Map&lt;felt252, u64&gt;,

// Is the implementation finalized.

finalized: bool,

}



#### Roles

In charge of access control in the contract.

#\[starknet::interface\]

pub trait IRoles&lt;TContractState&gt; {

fn is_app_governor(self: @TContractState, account: ContractAddress) -> bool;

fn is_app_role_admin(self: @TContractState, account: ContractAddress) -> bool;

fn is_governance_admin(self: @TContractState, account: ContractAddress) -> bool;

fn is_operator(self: @TContractState, account: ContractAddress) -> bool;

fn is_token_admin(self: @TContractState, account: ContractAddress) -> bool;

fn is_upgrade_governor(self: @TContractState, account: ContractAddress) -> bool;

fn is_security_admin(self: @TContractState, account: ContractAddress) -> bool;

fn is_security_agent(self: @TContractState, account: ContractAddress) -> bool;

fn register_app_governor(ref self: TContractState, account: ContractAddress);

fn remove_app_governor(ref self: TContractState, account: ContractAddress);

fn register_app_role_admin(ref self: TContractState, account: ContractAddress);

fn remove_app_role_admin(ref self: TContractState, account: ContractAddress);

fn register_governance_admin(ref self: TContractState, account: ContractAddress);

fn remove_governance_admin(ref self: TContractState, account: ContractAddress);

fn register_operator(ref self: TContractState, account: ContractAddress);

fn remove_operator(ref self: TContractState, account: ContractAddress);

fn register_token_admin(ref self: TContractState, account: ContractAddress);

fn remove_token_admin(ref self: TContractState, account: ContractAddress);

fn register_upgrade_governor(ref self: TContractState, account: ContractAddress);

fn remove_upgrade_governor(ref self: TContractState, account: ContractAddress);

fn renounce(ref self: TContractState, role: RoleId);

fn register_security_admin(ref self: TContractState, account: ContractAddress);

fn remove_security_admin(ref self: TContractState, account: ContractAddress);

fn register_security_agent(ref self: TContractState, account: ContractAddress);

fn remove_security_agent(ref self: TContractState, account: ContractAddress);

}



### Public methods

#### Trade

##### Description

fn trade(

self: @ContractState,

order_a: Order,

order_b: Order,

signature_a: Span&lt;felt252&gt;,

signature_b: Span&lt;felt252&gt;,

order_a_actual_sell_amount: u128,

order_a_actual_buy_amount: u128,

);



##### Access Control

Anyone can execute.

##### Validations

- Pausable check.
- Signature check.
- Expiration check.
- order_X.user is allowed address.
- order_a.user != order_b.user.
- order_X.sell_amount != 0.
- order_X.buy_amount != 0.
- Order_a_actual_sell_amount and Order_a_actual_buy_amount are non-zero.
- order_X.sell_token != order_X.buy_token, and are registered tokens.
- Check order_a.user is among the buyer_order.allowed_addresses.
- Check buyer_order.user is among the seller_order.allowed_addresses.
- order_a.sell_token == order_b.buy_token
- order_a.buy_token == order_b.sell_token
- order_a.sell_amount >= actual_sell_amount.
- order_a.buy_amount >= actual_buy_amount.
- order_b.sell_amount >= order_a_actual_buy_amount.
- order_b.buy_amount >= order_a_actual_sell_amount.
- order_a.sell_amount / order_a_actual_sell_amount ≤ order_a.buy_amount / order_a_actual_buy_amount
- order_b.sell_amount / order_a_actual_buy_amount ≤ order_b.buy_amount / order_a_actual_sell_amount
- Fulfillment\[order_hash_a\]+ order_a_actual_sell_amount≤order_a.sell_amount
- Fulfillment\[order_hash_b\]+ order_a_actual_buy_amount≤order_b.sell_amount

##### Logic

- Run Validations.
- Transfer fee from order_X.sell_token.
- Transfer money from both tokens.
- fulfillment\[order_hash_a\]+=|order_a_actual_sell_amount|
- fulfillment\[order_hash_b\]+=|order_a_actual_buy_amount|
- Emit TradeExecuted event.

####

#### SetDustLimit

##### Description

fn set_dust_limit(self: @ContractState, dust_limit: u128);



##### Access Control

Only the operator can execute.

##### Validations

- dust_limit is non zero.

##### Logic

- Run Validations.
- update dust_limit.
- Emit DustLimitSet event.

#### SetFee

##### Description

fn set_fee(self: @ContractState, fee: u128);



##### Access Control

Only the operator can execute.

##### Validations

- fee <= fee_limit.

##### Logic

- Run Validations.
- update fee.
- Emit SetFee event.

#### SetFeeRecipient

##### Description

fn set_fee_recipient(

self: @ContractState,

fee_recipient: ContractAddress

);



##### Access Control

Only the operator can execute.

##### Validations

- fee_recipient.is_non_zero()

##### Logic

- Run Validations.
- Update fee recipient.
- Emit FeeRecipientSet event.

#### CancelOrder

##### Description

Operator cancels partially fulfilled orders.

fn cancel_orders(

self: @ContractState,

orders: Span&lt;Order&gt;,

);



##### Access Control

Only the operator can execute.

##### Validations

##### Logic

- Calculate order hash.
- Update fulfillment to order.sell_amount (which would prevent trading the order).
- Emit OrderCanceled event.

#### GetOrderFulfillment

##### Description

fn get_order_fulfillment(

self: @ContractState,

order_hash: HashType,

);



##### Access Control

Anyone can execute.

##### Validations

##### Logic

- Return fulfillment value of order_hash.

#### RegisterToken

##### Description

fn register_token(

ref self: ContractState,

token: ContractAddress,

);



##### Access Control

Only the app Governor can execute.

##### Validations

- Token was not registered yet.
- Token is non zero.

##### Logic

- Run Validations.
- Add token to the token map.
- Emit TokenRegistered event.

#### RemoveToken

##### Description

fn remove_token(

ref self: ContractState,

token: ContractAddress,

);



##### Access Control

Only the app Governor can execute.

##### Validations

- Token was registered.

##### Logic

- Run Validations.
- Remove token from the token map.
- Emit TokenRemoved event.

#### IsTokenRegistered

##### Description

fn is_token_registered(

self: @ContractState,

token: ContractAddress,

);



##### Access Control

Anyone can execute.

##### Validations

- Check token is non-zero.

##### Logic

- Run validations.
- Check token map.

#### AddToAllowlist

##### Description

fn add_to_allowlist(

ref self: ContractState,

address: ContractAddress,

);



##### Access Control

Only the app Governor can execute.

##### Validations

- address was not added yet.
- address is non zero.

##### Logic

- Run Validations.
- Add address to the allowlist map.
- Emit AddressAllowed event.

#### RemoveFromAllowlist

##### Description

fn remove_from_allowlist(

ref self: ContractState,

address: ContractAddress,

);



##### Access Control

Only the app Governor can execute.

##### Validations

- address was registered.

##### Logic

- Run Validations.
- Remove address from the allowlist map.
- Emit AddressDisallowed event.

#### IsAllowed

##### Description

fn is_allowed(

self: @ContractState,

address: ContractAddress,

);



##### Access Control

Anyone can execute.

##### Validations

- Check token is non-zero.

##### Logic

- Run validations.
- Check allowlist map.

#### GetDustLimit

##### Description

fn get_dust_limit(self: @ContractState) -> u128;



##### Access Control

Anyone can execute.

##### Validations

##### Logic

- Read dust_limit.

#### GetFeeLimit

##### Description

fn get_fee_limit(self: @ContractState) -> u128;



##### Access Control

Anyone can execute.

##### Validations

##### Logic

- Read fee_limit.

#### GetFee

##### Description

fn get_fee(self: @ContractState) -> u128;



##### Access Control

Anyone can execute.

##### Validations

##### Logic

- Read fee.

#### GetFeeRecipient

##### Description

fn get_fee_recipient(self: @ContractState) -> ContractAddress;



##### Access Control

Anyone can execute.

##### Validations

##### Logic

- Read fee recipient.
