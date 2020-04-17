pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-dandelion-voting/contracts/DandelionVoting.sol";
import "@1hive/apps-redemptions/contracts/Redemptions.sol";
import "./external/ITollgate.sol";

contract GardensTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MEMBERSHIP_MISSING_MEMBERS";
    string constant private ERROR_BAD_VOTE_SETTINGS = "MEMBERSHIP_BAD_VOTE_SETTINGS";

    bool constant private TOKEN_TRANSFERABLE = false;
    uint8 constant private TOKEN_DECIMALS = uint8(0);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    uint64 constant private DEFAULT_FINANCE_PERIOD = uint64(30 days);
    address constant private ANY_ENTITY = address(-1);
    uint8 constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }

    struct DeployedContracts {
        Kernel dao;
        ACL acl;
        DandelionVoting dandelionVoting;
        Vault agentOrVault;
        TokenManager tokenManager;
    }

    mapping(address => DeployedContracts) internal senderDeployedContracts;

    constructor(DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory, IFIFSResolvingRegistrar _aragonID)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID)
        public
    {
        _ensureAragonIdIsValid(_aragonID);
        _ensureMiniMeFactoryIsValid(_miniMeFactory);
    }

    // New DAO functions //

    function createDaoTxOne(
        string _voteTokenName,
        string _voteTokenSymbol,
        address[] _members,
        uint64[5] _votingSettings,
        uint64 _financePeriod,
        bool _useAgentAsVault,
        bool _useConvictionAsFinance
    )
        public
    {
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

        _storeDeployedContractsTxOne(dao, acl, dandelionVoting, agentOrVault, tokenManager);
    }

    function createDaoTxTwo(string _id, ERC20 _tollgateFeeToken, uint256 _tollgateFeeAmount) external {
        _validateId(_id);
        (Kernel dao,
        ACL acl,
        DandelionVoting dandelionVoting,
        Vault agentOrVault,
        TokenManager tokenManager) = _getDeployedContracts();

        ITollgate tollgate = _installTollgate(dao, _tollgateFeeToken, _tollgateFeeAmount, address(agentOrVault));
        _createTollgatePermissions(acl, tollgate, dandelionVoting);

        Redemptions redemptions = _installRedemptions(dao, agentOrVault, tokenManager, new address[](0));
        _createRedemptionsPermissions(acl, redemptions, dandelionVoting);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, dandelionVoting);
        _registerID(_id, dao);
        _deleteStoredContracts();
    }

    // App installation functions //

    function _installDandelionVotingApp(Kernel _dao, MiniMeToken _voteToken, uint64[5] _votingSettings)
        internal returns (DandelionVoting)
    {
        bytes32 dandelionVotingAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("dandelion-voting")));
        DandelionVoting dandelionVoting = DandelionVoting(_installNonDefaultApp(_dao, dandelionVotingAppId));
        dandelionVoting.initialize(_voteToken, _votingSettings[0], _votingSettings[1], _votingSettings[2],
            _votingSettings[3], _votingSettings[4]);
        return dandelionVoting;
    }

    function _installTollgate(Kernel _dao, ERC20 _tollgateFeeToken, uint256 _tollgateFeeAmount, address _tollgateFeeDestination)
        internal returns (ITollgate)
    {
        bytes32 tollgateAppId = apmNamehash("tollgate");
        ITollgate tollgate = ITollgate(_installNonDefaultApp(_dao, tollgateAppId));
        tollgate.initialize(_tollgateFeeToken, _tollgateFeeAmount, _tollgateFeeDestination);
        return tollgate;
    }

    function _installRedemptions(Kernel _dao, Vault _vault, TokenManager _tokenManager, address[] _redeemableTokens)
        internal returns (Redemptions)
    {
        bytes32 redemptionsAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("redemptions")));
        Redemptions redemptions = Redemptions(_installNonDefaultApp(_dao, redemptionsAppId));
        redemptions.initialize(_vault, _tokenManager, _redeemableTokens);
        return redemptions;
    }

    // Permission setting functions //

    function _createCustomVotingPermissions(ACL _acl, DandelionVoting _dandelionVoting, TokenManager _tokenManager)
        internal
    {
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_QUORUM_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_SUPPORT_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_BUFFER_BLOCKS_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_EXECUTION_DELAY_ROLE(), _dandelionVoting);
    }

    function _createCustomTokenManagerPermissions(ACL _acl, TokenManager _tokenManager, DandelionVoting _dandelionVoting)
        internal
    {
        _acl.createPermission(_dandelionVoting, _tokenManager, _tokenManager.BURN_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _tokenManager, _tokenManager.MINT_ROLE(), _dandelionVoting);
    }

    function _createTollgatePermissions(ACL _acl, ITollgate _tollgate, DandelionVoting _dandelionVoting) internal {
        _acl.createPermission(_dandelionVoting, _tollgate, _tollgate.CHANGE_AMOUNT_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _tollgate, _tollgate.CHANGE_DESTINATION_ROLE(), _dandelionVoting);
        _acl.createPermission(_tollgate, _dandelionVoting, _dandelionVoting.CREATE_VOTES_ROLE(), _dandelionVoting);
    }

    function _createRedemptionsPermissions(ACL _acl, Redemptions _redemptions, DandelionVoting _dandelionVoting) internal {
        _acl.createPermission(ANY_ENTITY, _redemptions, _redemptions.REDEEM_ROLE(), address(this));
        _setOracle(_acl, ANY_ENTITY, _redemptions, _redemptions.REDEEM_ROLE(), _dandelionVoting);
        _acl.setPermissionManager(_dandelionVoting, _redemptions, _redemptions.REDEEM_ROLE());

        _acl.createPermission(_dandelionVoting, _redemptions, _redemptions.ADD_TOKEN_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _redemptions, _redemptions.REMOVE_TOKEN_ROLE(), _dandelionVoting);
    }

    // Validation functions //

    function _ensureMembershipSettings(address[] memory _members, uint64[5] memory _votingSettings) private pure {
        require(_members.length > 0, ERROR_MISSING_MEMBERS);
        require(_votingSettings.length == 5, ERROR_BAD_VOTE_SETTINGS);
    }

    // Temporary Storage functions //

    function _storeDeployedContractsTxOne(Kernel _dao, ACL _acl, DandelionVoting _dandelionVoting, Vault _agentOrVault, TokenManager _tokenManager) internal {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.dao = _dao;
        deployedContracts.acl = _acl;
        deployedContracts.dandelionVoting = _dandelionVoting;
        deployedContracts.agentOrVault = _agentOrVault;
        deployedContracts.tokenManager = _tokenManager;
    }

    function _getDeployedContracts() internal returns (Kernel, ACL, DandelionVoting, Vault, TokenManager) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.dao,
            deployedContracts.acl,
            deployedContracts.dandelionVoting,
            deployedContracts.agentOrVault,
            deployedContracts.tokenManager
        );
    }

    function _deleteStoredContracts() internal {
        delete senderDeployedContracts[msg.sender];
    }

    // Oracle permissions with params functions //

    function _setOracle(ACL _acl, address _who, address _where, bytes32 _what, address _oracle) private {
        uint256[] memory params = new uint256[](1);
        params[0] = _paramsTo256(ORACLE_PARAM_ID, uint8(Op.EQ), uint240(_oracle));

        _acl.grantPermissionP(_who, _where, _what, params);
    }

    function _paramsTo256(uint8 _id,uint8 _op, uint240 _value) private returns (uint256) {
        return (uint256(_id) << 248) + (uint256(_op) << 240) + _value;
    }
}