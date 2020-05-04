pragma solidity 0.4.24;

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

contract IHookedTokenManager {

    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant ISSUE_ROLE = keccak256("ISSUE_ROLE");
    bytes32 public constant ASSIGN_ROLE = keccak256("ASSIGN_ROLE");
    bytes32 public constant REVOKE_VESTINGS_ROLE = keccak256("REVOKE_VESTINGS_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant SET_HOOK_ROLE = keccak256("SET_HOOK_ROLE");

    MiniMeToken public token;

    function initialize(MiniMeToken _token, bool _transferable, uint256 _maxAccountTokens) external;

    function registerHook(address _hook) external returns (uint256);
}