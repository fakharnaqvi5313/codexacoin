// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice A wrapped, reserve-backed representation of CAC on Base --
/// an IOU, not a bridge, exactly like the Stellar CAC asset (see
/// stellar-issuer/README.md for why no trustless bridge is possible for
/// an external UTXO chain). The entire supply mints once, here, at
/// construction. There is no owner, no mint function, and no admin
/// role of any kind -- unlike the Stellar issuer key (which still has
/// to be manually locked to cap supply), this contract is provably
/// incapable of further issuance from the moment it's deployed.
contract CodexaCoinBase is ERC20 {
    constructor(uint256 initialSupply, address reserveBackedRecipient)
        ERC20("CodexaCoin", "CAC")
    {
        _mint(reserveBackedRecipient, initialSupply);
    }
}
