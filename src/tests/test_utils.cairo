use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::declare_and_deploy;
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::signature::{KeyPair, KeyPairTrait};
use snforge_std::{Token, TokenImpl, TokenTrait, set_balance};
use starknet::ContractAddress;
use starkware_utils::time::time::Timestamp;
use starkware_utils_testing::{constants as testing_constants, test_utils};
use crate::order::Order;
use crate::payments::payments::SNIP12MetadataImpl;

pub mod constants {
    use super::*;
    pub const UPGRADE_DELAY: u64 = 0;
    pub const DUST_LIMIT: u128 = 10000;
    pub const FEE_LIMIT: u128 = 1000;
    pub const FEE_RECIPIENT: ContractAddress = 'FEE_RECIPIENT'.try_into().unwrap();
    pub const FEE: u128 = 100;
    pub const INITIAL_BALANCE: u256 = 100_000_000;
}

fn deploy_contract() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(testing_constants::GOVERNANCE_ADMIN);
    calldata.append_serde(constants::UPGRADE_DELAY);
    calldata.append_serde(constants::DUST_LIMIT);
    calldata.append_serde(constants::FEE_LIMIT);
    calldata.append_serde(constants::FEE_RECIPIENT);
    calldata.append_serde(constants::FEE);
    declare_and_deploy("payments", calldata)
}

pub fn init_contract_with_roles() -> ContractAddress {
    let contract_address = deploy_contract();
    test_utils::set_default_roles(
        contract: contract_address, governance_admin: testing_constants::GOVERNANCE_ADMIN,
    );
    contract_address
}

pub fn test_setup(
    initial_balance: u256,
) -> (
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    KeyPair<felt252, felt252>,
    KeyPair<felt252, felt252>,
) {
    let contract_address = init_contract_with_roles();

    let secret_key_a = 1;
    let key_pair_a = KeyPairTrait::from_secret_key(secret_key_a);
    let public_key_a = key_pair_a.public_key;
    let user_a = declare_and_deploy("SRC9AccountMock", array![public_key_a]);

    let secret_key_b = 1;
    let key_pair_b = KeyPairTrait::from_secret_key(secret_key_b);
    let public_key_b = key_pair_b.public_key;
    let user_b = declare_and_deploy("SRC9AccountMock", array![public_key_b]);

    let token_a = Token::STRK.contract_address();
    let token_b = Token::ETH.contract_address();

    set_balance(user_a, initial_balance, Token::STRK);
    set_balance(user_b, initial_balance, Token::ETH);

    (contract_address, token_a, token_b, user_a, user_b, key_pair_a, key_pair_b)
}

pub fn default_order() -> Order {
    Order {
        salt: 0,
        expiry: Timestamp { seconds: 0 },
        user: testing_constants::DUMMY_ADDRESS,
        sell_token: testing_constants::DUMMY_ADDRESS,
        buy_token: testing_constants::DUMMY_ADDRESS,
        sell_amount: 100,
        buy_amount: 200,
        approved_counterparties: array![].span(),
    }
}
