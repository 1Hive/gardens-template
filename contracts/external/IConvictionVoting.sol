pragma solidity ^0.4.24;

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@aragon/apps-vault/contracts/Vault.sol";

contract IConvictionVoting {

    bytes32 constant public CREATE_PROPOSALS_ROLE = keccak256("CREATE_PROPOSALS_ROLE");

    function initialize(MiniMeToken _stakeToken, Vault _vault, address _requestToken) public;

    function initialize(MiniMeToken _stakeToken, Vault _vault, address _requestToken, uint256 _decay, uint256 _maxRatio);

    function initialize(
        MiniMeToken _stakeToken,
        Vault _vault,
        address _requestToken,
        uint256 _decay,
        uint256 _maxRatio,
        uint256 _weight
    ) public;
}
