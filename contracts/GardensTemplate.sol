pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-dandelion-voting/contracts/DandelionVoting.sol";
import "@1hive/apps-redemptions/contracts/Redemptions.sol";
import "./external/ITollgate.sol";
import "./external/IConvictionVoting.sol";
import "@ablack/fundraising-bancor-formula/contracts/BancorFormula.sol";
import {AragonFundraisingController as Controller} from "@ablack/fundraising-aragon-fundraising/contracts/AragonFundraisingController.sol";
import {BatchedBancorMarketMaker as MarketMaker} from "@ablack/fundraising-batched-bancor-market-maker/contracts/BatchedBancorMarketMaker.sol";
import "@ablack/fundraising-presale/contracts/Presale.sol";
import "@ablack/fundraising-tap/contracts/Tap.sol";

// TODO: Add doc strings
// TODO: Error checking for cached contracts
contract GardensTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MEMBERSHIP_MISSING_MEMBERS";
    string constant private ERROR_BAD_VOTE_SETTINGS = "MEMBERSHIP_BAD_VOTE_SETTINGS";

    bytes32 private constant BANCOR_FORMULA_ID = 0xd71dde5e4bea1928026c1779bde7ed27bd7ef3d0ce9802e4117631eb6fa4ed7d;
    bytes32 private constant PRESALE_ID = 0x5de9bbdeaf6584c220c7b7f1922383bcd8bbcd4b48832080afd9d5ebf9a04df5;
    bytes32 private constant MARKET_MAKER_ID= 0xc2bb88ab974c474221f15f691ed9da38be2f5d37364180cec05403c656981bf0;
    bytes32 private constant ARAGON_FUNDRAISING_ID = 0x668ac370eed7e5861234d1c0a1e512686f53594fcb887e5bcecc35675a4becac;
    bytes32 private constant TAP_ID = 0x82967efab7144b764bc9bca2f31a721269b6618c0ff4e50545737700a5e9c9dc;

    bool constant private TOKEN_TRANSFERABLE = false;
    uint8 constant private TOKEN_DECIMALS = uint8(0);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    uint64 constant private DEFAULT_FINANCE_PERIOD = uint64(30 days);
    address constant private ANY_ENTITY = address(-1);
    uint8 constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }

    uint256 private constant BUY_FEE_PCT = 0;
    uint256 private constant SELL_FEE_PCT = 0;

    struct DeployedContracts {
        address[] collaterals;
        Kernel dao;
        ACL acl;
        DandelionVoting dandelionVoting;
        Vault agentOrVault;
        TokenManager tokenManager;
        Agent reserve;
        Presale presale;
        MarketMaker marketMaker;
        Tap tap;
        Controller controller;
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
        bool _useAgentAsVault
    )
        public
    {
        _ensureMembershipSettings(_members, _votingSettings);

        (Kernel dao, ACL acl) = _createDAO();
        MiniMeToken voteToken = _createToken(_voteTokenName, _voteTokenSymbol, TOKEN_DECIMALS);
        Vault agentOrVault = _useAgentAsVault ? _installDefaultAgentApp(dao) : _installVaultApp(dao);
        DandelionVoting dandelionVoting = _installDandelionVotingApp(dao, voteToken, _votingSettings);
        TokenManager tokenManager = _installTokenManagerApp(dao, voteToken, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);

        // Mint tokens (will be done using fundraising)
        _mintTokens(acl, tokenManager, _members, 1);

        // Set up permissions
        if (_useAgentAsVault) {
            _createAgentPermissions(acl, Agent(agentOrVault), dandelionVoting, dandelionVoting);
        }
        _createEvmScriptsRegistryPermissions(acl, dandelionVoting, dandelionVoting);
        _createCustomVotingPermissions(acl, dandelionVoting, tokenManager);
        _createCustomTokenManagerPermissions(acl, tokenManager, dandelionVoting);

        _storeDeployedContractsTxOne(dao, acl, dandelionVoting, agentOrVault, tokenManager);
    }

    function createDaoTxTwo(
        ERC20 _tollgateFeeToken,
        uint256 _tollgateFeeAmount,
        bool _useConvictionAsFinance,
        ERC20 _convictionVotingRequestToken,
        uint64 _financePeriod
    )
        public
    {
        (Kernel dao,
        ACL acl,
        DandelionVoting dandelionVoting,
        Vault agentOrVault,
        TokenManager tokenManager) = _getDeployedContractsTxOne();

        ITollgate tollgate = _installTollgate(dao, _tollgateFeeToken, _tollgateFeeAmount, address(agentOrVault));
        _createTollgatePermissions(acl, tollgate, dandelionVoting);

        Redemptions redemptions = _installRedemptions(dao, agentOrVault, tokenManager, new address[](0));
        _createRedemptionsPermissions(acl, redemptions, dandelionVoting);

        if (_useConvictionAsFinance) {
            IConvictionVoting convictionVoting = _installConvictionVoting(dao, tokenManager.token(), agentOrVault, _convictionVotingRequestToken);
            _createConvictionVotingPermissions(acl, convictionVoting, dandelionVoting);
        } else {
            Finance finance = _installFinanceApp(dao, agentOrVault, _financePeriod == 0 ? DEFAULT_FINANCE_PERIOD : _financePeriod);
            _createVaultPermissions(acl, agentOrVault, finance, dandelionVoting);
            _createFinancePermissions(acl, finance, dandelionVoting, dandelionVoting);
        }
    }

    function createDaoTxThree(
        uint256 _goal,
        uint64  _period,
        uint256 _exchangeRate,
        uint64  _vestingCliffPeriod,
        uint64  _vestingCompletePeriod,
        uint256 _supplyOfferedPct,
        uint256 _fundingForBeneficiaryPct,
        uint64  _openDate,
        uint256 _batchBlocks,
        uint256 _maxTapRateIncreasePct,
        uint256 _maxTapFloorDecreasePct,
        address[] _collaterals
    )
        external
    {
        (Kernel dao,,,,) = _getDeployedContractsTxOne();

        _installFundraisingApps(
            dao,
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            _batchBlocks,
            _maxTapRateIncreasePct,
            _maxTapFloorDecreasePct,
            _collaterals
        );
        // setup share apps permissions [now that fundraising apps have been installed]
//        _setupSharePermissions(dao);
        // setup fundraising apps permissions
//        _setupFundraisingPermissions(dao);
    }

    function createDaoTxFour(string _id) external {
        _validateId(_id);
        (Kernel dao,,DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();

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

    function _installRedemptions(Kernel _dao, Vault _agentOrVault, TokenManager _tokenManager, address[] _redeemableTokens)
        internal returns (Redemptions)
    {
        bytes32 redemptionsAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("redemptions")));
        Redemptions redemptions = Redemptions(_installNonDefaultApp(_dao, redemptionsAppId));
        redemptions.initialize(_agentOrVault, _tokenManager, _redeemableTokens);
        return redemptions;
    }

    function _installConvictionVoting(Kernel _dao, MiniMeToken _stakeToken, Vault _agentOrVault, address _requestToken)
        internal returns (IConvictionVoting)
    {
        bytes32 convictionVotingAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("conviction-voting")));
        IConvictionVoting convictionVoting = IConvictionVoting(_installNonDefaultApp(_dao, convictionVotingAppId));
        convictionVoting.initialize(_stakeToken, _agentOrVault, _requestToken);
        return convictionVoting;
    }

    function _installFundraisingApps(
        Kernel  _dao,
        uint256 _goal,
        uint64  _period,
        uint256 _exchangeRate,
        uint64  _vestingCliffPeriod,
        uint64  _vestingCompletePeriod,
        uint256 _supplyOfferedPct,
        uint256 _fundingForBeneficiaryPct,
        uint64  _openDate,
        uint256 _batchBlocks,
        uint256 _maxTapRateIncreasePct,
        uint256 _maxTapFloorDecreasePct,
        address[] _collaterals
    )
        internal
    {
        _proxifyFundraisingApps(_dao);

        _initializePresale(
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            _collaterals
        );
        _initializeMarketMaker(_batchBlocks);
        _initializeTap(_batchBlocks, _maxTapRateIncreasePct, _maxTapFloorDecreasePct);
        _initializeController(_collaterals);
    }

    function _proxifyFundraisingApps(Kernel _dao) internal {
        Agent reserve = _installNonDefaultAgentApp(_dao);
        Presale presale = Presale(_installNonDefaultApp(_dao, PRESALE_ID));
        MarketMaker marketMaker = MarketMaker(_installNonDefaultApp(_dao, MARKET_MAKER_ID));
        Tap tap = Tap(_installNonDefaultApp(_dao, TAP_ID));
        Controller controller = Controller(_installNonDefaultApp(_dao, ARAGON_FUNDRAISING_ID));

        _storeDeployedContractsTxThree(reserve, presale, marketMaker, tap, controller);
    }

    function _initializePresale(
        uint256 _goal,
        uint64  _period,
        uint256 _exchangeRate,
        uint64  _vestingCliffPeriod,
        uint64  _vestingCompletePeriod,
        uint256 _supplyOfferedPct,
        uint256 _fundingForBeneficiaryPct,
        uint64  _openDate,
        address[] _collaterals
    )
        internal
    {
        // Accessing deployed contracts directly due to stack too deep error.
        senderDeployedContracts[msg.sender].presale.initialize(
            senderDeployedContracts[msg.sender].controller,
            senderDeployedContracts[msg.sender].tokenManager,
            senderDeployedContracts[msg.sender].reserve,
            senderDeployedContracts[msg.sender].agentOrVault,
            _collaterals[0],
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate
        );
    }

    function _initializeMarketMaker(uint256 _batchBlocks) internal {
        IBancorFormula bancorFormula = IBancorFormula(_latestVersionAppBase(BANCOR_FORMULA_ID));

        (Kernel dao,,, Vault beneficiary, TokenManager tokenManager) = _getDeployedContractsTxOne();
        (Agent reserve,, MarketMaker marketMaker,, Controller controller) = _getDeployedContractsTxThree();

        marketMaker.initialize(controller, tokenManager, bancorFormula, reserve, beneficiary, _batchBlocks, BUY_FEE_PCT, SELL_FEE_PCT);
    }

    function _initializeTap(uint256 _batchBlocks, uint256 _maxTapRateIncreasePct, uint256 _maxTapFloorDecreasePct) internal {
        (,,, Vault beneficiary,) = _getDeployedContractsTxOne();
        (Agent reserve,,, Tap tap, Controller controller) = _getDeployedContractsTxThree();

        tap.initialize(controller, reserve, beneficiary, _batchBlocks, _maxTapRateIncreasePct, _maxTapFloorDecreasePct);
    }

    function _initializeController(address[] _collaterals) internal {
        (Agent reserve, Presale presale, MarketMaker marketMaker, Tap tap, Controller controller) = _getDeployedContractsTxThree();
        address[] memory toReset = new address[](1);
        toReset[0] = _collaterals[0];
        controller.initialize(presale, marketMaker, reserve, tap, toReset);
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

    function _createRedemptionsPermissions(ACL _acl, Redemptions _redemptions, DandelionVoting _dandelionVoting)
        internal
    {
        _acl.createPermission(ANY_ENTITY, _redemptions, _redemptions.REDEEM_ROLE(), address(this));
        _setOracle(_acl, ANY_ENTITY, _redemptions, _redemptions.REDEEM_ROLE(), _dandelionVoting);
        _acl.setPermissionManager(_dandelionVoting, _redemptions, _redemptions.REDEEM_ROLE());

        _acl.createPermission(_dandelionVoting, _redemptions, _redemptions.ADD_TOKEN_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _redemptions, _redemptions.REMOVE_TOKEN_ROLE(), _dandelionVoting);
    }

    function _createConvictionVotingPermissions(ACL _acl, IConvictionVoting _convictionVoting, DandelionVoting _dandelionVoting)
        internal
    {
        _acl.createPermission(ANY_ENTITY, _convictionVoting, _convictionVoting.CREATE_PROPOSALS_ROLE(), _dandelionVoting);
    }

    // Validation functions //

    function _ensureMembershipSettings(address[] memory _members, uint64[5] memory _votingSettings) private pure {
        require(_members.length > 0, ERROR_MISSING_MEMBERS);
        require(_votingSettings.length == 5, ERROR_BAD_VOTE_SETTINGS);
    }

    // Temporary Storage functions //

    function _storeDeployedContractsTxOne(Kernel _dao, ACL _acl, DandelionVoting _dandelionVoting, Vault _agentOrVault, TokenManager _tokenManager)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.dao = _dao;
        deployedContracts.acl = _acl;
        deployedContracts.dandelionVoting = _dandelionVoting;
        deployedContracts.agentOrVault = _agentOrVault;
        deployedContracts.tokenManager = _tokenManager;
    }

    function _getDeployedContractsTxOne() internal returns (Kernel, ACL, DandelionVoting, Vault, TokenManager) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.dao,
            deployedContracts.acl,
            deployedContracts.dandelionVoting,
            deployedContracts.agentOrVault,
            deployedContracts.tokenManager
        );
    }

    function _storeDeployedContractsTxThree(Agent _reserve, Presale _presale, MarketMaker _marketMaker, Tap _tap, Controller _controller)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.reserve = _reserve;
        deployedContracts.presale = _presale;
        deployedContracts.marketMaker = _marketMaker;
        deployedContracts.tap = _tap;
        deployedContracts.controller = _controller;
    }

    function _getDeployedContractsTxThree() internal returns (Agent, Presale, MarketMaker, Tap, Controller) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.reserve,
            deployedContracts.presale,
            deployedContracts.marketMaker,
            deployedContracts.tap,
            deployedContracts.controller
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