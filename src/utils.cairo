use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
use starknet::ContractAddress;
use crate::errors::INVALID_STARK_SIGNATURE;

// TODO(Mohammad): check if similar util is already implemented. if not move it to `starkware_utils`
// repo.
fn is_in_span(tested_address: ContractAddress, address_list: Span<ContractAddress>) -> bool {
    for addr in address_list {
        if *addr == tested_address {
            return true;
        }
    }
    false
}

pub fn is_allowed_address(
    tested_address: ContractAddress, allowed_addresses: Span<ContractAddress>,
) -> bool {
    // Means all addresses are allowed.
    if allowed_addresses.len() == 0 {
        return true;
    }

    is_in_span(tested_address, allowed_addresses)
}

pub fn validate_signature(signer: ContractAddress, hash: felt252, signature: Span<felt252>) {
    let is_valid_signature_felt = ISRC6Dispatcher { contract_address: signer }
        .is_valid_signature(hash, signature.into());

    // Check either 'VALID' or true for backwards compatibility
    let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
        || is_valid_signature_felt == 1;

    assert(is_valid_signature, INVALID_STARK_SIGNATURE);
}

