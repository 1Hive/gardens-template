pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-dandelion-voting/contracts/DandelionVoting.sol";

contract GardensTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MEMBERSHIP_MISSING_MEMBERS";
    string constant private ERROR_BAD_VOTE_SETTINGS = "MEMBERSHIP_BAD_VOTE_SETTINGS";

    bool constant private TOKEN_TRANSFERABLE = false;
    uint8 constant private TOKEN_DECIMALS = uint8(0);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    uint64 constant private DEFAULT_FINANCE_PERIOD = uint64(30 days);

    constructor(DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory, IFIFSResolvingRegistrar _aragonID)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID)
        public
    {
        _ensureAragonIdIsValid(_aragonID);
        _ensureMiniMeFactoryIsValid(_miniMeFactory);
    }

    function createDao(
        string _voteTokenName,
        string _voteTokenSymbol,
        string _id,
        address[] _members,
        uint64[5] _votingSettings,
        uint64 _financePeriod,
        bool _useAgentAsVault,
        bool _useConvictionAsFinance
    )
        public
    {
        _validateId(_id);
        _ensureMembershipSettings(_members, _votingSettings);

        (Kernel dao, ACL acl) = _createDAO();
        MiniMeToken voteToken = _createToken(_voteTokenName, _voteTokenSymbol, TOKEN_DECIMALS);
        TokenManager tokenManager = _installTokenManagerApp(dao, voteToken, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);
        DandelionVoting dandelionVoting = _installDandelionVotingApp(dao, voteToken, _votingSettings);
        Vault agentOrVault = _useAgentAsVault ? _installDefaultAgentApp(dao) : _installVaultApp(dao);
        Finance finance = _useConvictionAsFinance ? _installFinanceApp(dao, agentOrVault, DEFAULT_FINANCE_PERIOD) : _installFinanceApp(dao, agentOrVault, DEFAULT_FINANCE_PERIOD);

        // Mint tokens
        _mintTokens(acl, tokenManager, _members, 1);

        // Set up permissions
        if (_useAgentAsVault) {
            _createAgentPermissions(acl, Agent(agentOrVault), dandelionVoting, dandelionVoting);
        }
        _createVaultPermissions(acl, agentOrVault, finance, dandelionVoting);
        if (!_useConvictionAsFinance) {
            _createFinancePermissions(acl, finance, dandelionVoting, dandelionVoting);
        }
        _createEvmScriptsRegistryPermissions(acl, dandelionVoting, dandelionVoting);
        _createCustomVotingPermissions(acl, dandelionVoting, tokenManager);
        _createCustomTokenManagerPermissions(acl, tokenManager, dandelionVoting);
        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, dandelionVoting);

        _registerID(_id, dao);
    }

    function _installDandelionVotingApp(Kernel _dao, MiniMeToken _voteToken, uint64[5] _votingSettings)
        internal returns (DandelionVoting)
    {
        bytes32 dandelionVotingAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("dandelion-voting")));
        DandelionVoting dandelionVoting = DandelionVoting(_installNonDefaultApp(_dao, dandelionVotingAppId));
        dandelionVoting.initialize(_voteToken, _votingSettings[0], _votingSettings[1], _votingSettings[2],
            _votingSettings[3], _votingSettings[4]);
        return dandelionVoting;
    }

    function _createCustomVotingPermissions(ACL _acl, DandelionVoting _dandelionVoting, TokenManager _tokenManager) internal {
        _acl.createPermission(_tokenManager, _dandelionVoting, _dandelionVoting.CREATE_VOTES_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_QUORUM_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_SUPPORT_ROLE(), _dandelionVoting);
    }

    function _createCustomTokenManagerPermissions(ACL _acl, TokenManager _tokenManager, DandelionVoting _dandelionVoting) internal {
        _acl.createPermission(_dandelionVoting, _tokenManager, _tokenManager.BURN_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _tokenManager, _tokenManager.MINT_ROLE(), _dandelionVoting);
    }

    function _ensureMembershipSettings(address[] memory _members, uint64[5] memory _votingSettings) private pure {
        require(_members.length > 0, ERROR_MISSING_MEMBERS);
        require(_votingSettings.length == 5, ERROR_BAD_VOTE_SETTINGS);
    }
}