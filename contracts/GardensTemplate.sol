pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-dandelion-voting/contracts/DandelionVoting.sol";
import "@1hive/apps-redemptions/contracts/Redemptions.sol";
import "./external/ITollgate.sol";
import "./external/IConvictionVoting.sol";
import "@ablack/fundraising-bancor-formula/contracts/BancorFormula.sol";
import {IAragonFundraisingController as Controller} from "./external/IAragonFundraisingController.sol";
import "@ablack/fundraising-aragon-fundraising/contracts/AragonFundraisingController.sol";
import {BatchedBancorMarketMaker as MarketMaker} from "@ablack/fundraising-batched-bancor-market-maker/contracts/BatchedBancorMarketMaker.sol";
import "@ablack/fundraising-presale/contracts/Presale.sol";
import "@ablack/fundraising-tap/contracts/Tap.sol";

// TODO: Add doc strings
// TODO: Error checking for cached contracts
contract GardensTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "WRONG_MEMBS";
    string constant private ERROR_BAD_VOTE_SETTINGS = "BAD_SETT";

    /**
    * bytes32 private constant DANDELION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("dandelion-voting")));
    * bytes32 private constant REDEMPTIONS_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("redemptions")));
    * bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("conviction-voting")));
    * bytes32 private constant TOLLGATE_APP_ID = apmNamehash("tollgate");
    * bytes32 private constant BANCOR_FORMULA_ID = apmNamehash("bancor-formula");
    * bytes32 private constant PRESALE_ID = apmNamehash("presale");
    * bytes32 private constant MARKET_MAKER_ID = apmNamehash("batched-bancor-market-maker");
    * bytes32 private constant ARAGON_FUNDRAISING_ID = apmNamehash("aragon-fundraising");
    * bytes32 private constant TAP_ID = apmNamehash("tap");
    */
    bytes32 private constant DANDELION_VOTING_APP_ID = 0xf1a28fda6bef4895d111ff59fd86be63fa1a9d61868303e3ff6368363b4c687f; // Local
    bytes32 private constant REDEMPTIONS_APP_ID = 0xbf9fefd9508fe20f068aa3714e9beb8c4fc6dea33dc4c75371b96140d6350d20; // Local
    bytes32 private constant CONVICTION_VOTING_APP_ID = 0x589851b3734f6578a92f33bfc26877a1166b95238be1f484deeaac6383d14c38; // Local
    bytes32 private constant TOLLGATE_APP_ID = 0x7075e547e73484f0736b2160fcfb010b4f32b751fc729c25b677a0347d9b4246; // Local

//    bytes32 private constant DANDELION_VOTING_APP_ID = 0x2d7442e1c4cb7a7013aecc419f938bdfa55ad32d90002fb92ee5969e27b2bf07; // Rinkeby
//    bytes32 private constant REDEMPTIONS_APP_ID = 0x743bd419d5c9061290b181b19e114f36e9cc9ddb42b4e54fc811edb22eb85e9d; // Rinkeby
//    bytes32 private constant CONVICTION_VOTING_APP_ID = 0x16c0b0af27b5e169e5f678055840d7ab2b312519d7700a06554c287619f4b9f9; // Rinkeby
//    bytes32 private constant TOLLGATE_APP_ID = 0x0d321283289e70165ef6db7f11fc62c74a7d39dac3ee148428c4f9e3d74c6d61; // Rinkeby

    bytes32 private constant BANCOR_FORMULA_ID = 0xd71dde5e4bea1928026c1779bde7ed27bd7ef3d0ce9802e4117631eb6fa4ed7d;
    bytes32 private constant PRESALE_ID = 0x5de9bbdeaf6584c220c7b7f1922383bcd8bbcd4b48832080afd9d5ebf9a04df5;
    bytes32 private constant MARKET_MAKER_ID= 0xc2bb88ab974c474221f15f691ed9da38be2f5d37364180cec05403c656981bf0;
    bytes32 private constant ARAGON_FUNDRAISING_ID = 0x668ac370eed7e5861234d1c0a1e512686f53594fcb887e5bcecc35675a4becac;
    bytes32 private constant TAP_ID = 0x82967efab7144b764bc9bca2f31a721269b6618c0ff4e50545737700a5e9c9dc;

    bool private constant TOKEN_TRANSFERABLE = false;
    uint8 private constant TOKEN_DECIMALS = uint8(18);
    uint256 private constant TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    uint64 private constant DEFAULT_FINANCE_PERIOD = uint64(30 days);
    address private constant ANY_ENTITY = address(-1);
    uint8 private constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }

    // TODO: Pass these in?
    uint32 private constant PRIMARY_RESERVE_RATIO = 100000; // 10%
    uint32 private constant SECONDARY_RESERVE_RATIO = 10000;  // 1%

    struct DeployedContracts {
        address[] collateralTokens;
        Kernel dao;
        ACL acl;
        DandelionVoting dandelionVoting;
        Vault fundingPoolVault;
        TokenManager tokenManager;
        Vault reserveVault;
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
        require(_members.length > 0, ERROR_MISSING_MEMBERS);
        require(_votingSettings.length == 5, ERROR_BAD_VOTE_SETTINGS);

        (Kernel dao, ACL acl) = _createDAO();
        MiniMeToken voteToken = _createToken(_voteTokenName, _voteTokenSymbol, TOKEN_DECIMALS);
        Vault fundingPoolVault = _useAgentAsVault ? _installDefaultAgentApp(dao) : _installVaultApp(dao);
        DandelionVoting dandelionVoting = _installDandelionVotingApp(dao, voteToken, _votingSettings);
        TokenManager tokenManager = _installTokenManagerApp(dao, voteToken, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);

        if (_useAgentAsVault) {
            _createAgentPermissions(acl, Agent(fundingPoolVault), dandelionVoting, dandelionVoting);
        }
        _createEvmScriptsRegistryPermissions(acl, dandelionVoting, dandelionVoting);
        _createCustomVotingPermissions(acl, dandelionVoting, tokenManager);

        _storeDeployedContractsTxOne(dao, acl, dandelionVoting, fundingPoolVault, tokenManager);
    }

    function createDaoTxTwo(
        ERC20 _tollgateFeeToken,
        uint256 _tollgateFeeAmount,
        address[] _redeemableTokens,
        bool _useConvictionAsFinance,
        ERC20 _convictionVotingRequestToken,
        uint64 _financePeriod
    )
        public
    {
        (Kernel dao,
        ACL acl,
        DandelionVoting dandelionVoting,
        Vault fundingPoolVault,) = _getDeployedContractsTxOne();

        ITollgate tollgate = _installTollgate(dao, _tollgateFeeToken, _tollgateFeeAmount, address(fundingPoolVault));
        _createTollgatePermissions(acl, tollgate, dandelionVoting);

        Redemptions redemptions = _installRedemptions(dao, fundingPoolVault, senderDeployedContracts[msg.sender].tokenManager, _redeemableTokens);
        _createRedemptionsPermissions(acl, redemptions, dandelionVoting);

        if (_useConvictionAsFinance) {
            IConvictionVoting convictionVoting = _installConvictionVoting(dao, senderDeployedContracts[msg.sender].tokenManager.token(), fundingPoolVault, _convictionVotingRequestToken);
            _createVaultPermissions(acl, fundingPoolVault, convictionVoting, dandelionVoting);
            _createConvictionVotingPermissions(acl, convictionVoting, dandelionVoting);
        } else {
            Finance finance = _installFinanceApp(dao, fundingPoolVault, _financePeriod == 0 ? DEFAULT_FINANCE_PERIOD : _financePeriod);
            _createVaultPermissions(acl, fundingPoolVault, finance, dandelionVoting);
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
        uint256 _buyFeePct,
        uint256 _sellFeePct,
        uint256 _maxTapRateIncreasePct,
        uint256 _maxTapFloorDecreasePct,
        address[] _collateralTokens
    )
        public
    {
        _installFundraisingApps(
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            _batchBlocks,
            _buyFeePct,
            _sellFeePct,
            _maxTapRateIncreasePct,
            _maxTapFloorDecreasePct,
            _collateralTokens
        );

        _createCustomTokenManagerPermissions();
        _createFundraisingPermissions();
        _storeCollateralTokens(_collateralTokens);
    }

    function createDaoTxFour(
        string _id,
        uint256[2] _virtualSupplies,
        uint256[2] _virtualBalances,
        uint256[2] _slippages,
        uint256 _tapRate,
        uint256 _tapFloor
    )
        public
    {
        _validateId(_id);
        (Kernel dao, ACL acl, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();

        _setupCollateralTokens(dao, acl, _virtualSupplies, _virtualBalances, _slippages, _tapRate, _tapFloor);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, dandelionVoting);
        _registerID(_id, dao);
        _deleteStoredContracts();
    }

    function _setupCollateralTokens(
        Kernel _dao,
        ACL _acl,
        uint256[2] _virtualSupplies,
        uint256[2] _virtualBalances,
        uint256[2] _slippages,
        uint256 _tapRate,
        uint256 _tapFloor
    )
        internal
    {
        (,, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();
        (,,,, Controller controller) = _getDeployedContractsTxThree();
        address[] memory collateralTokens = _getCollateralTokens();

        // create and grant ADD_COLLATERAL_TOKEN_ROLE to this template
        _createPermissionForTemplate(_acl, address(controller), controller.ADD_COLLATERAL_TOKEN_ROLE());
        // add primary collateral both as a protected collateral and a tapped token
        controller.addCollateralToken(
            collateralTokens[0],
            _virtualSupplies[0],
            _virtualBalances[0],
            PRIMARY_RESERVE_RATIO,
            _slippages[0],
            _tapRate,
            _tapFloor
        );
        // add secondary collateral as a protected collateral [but not as a tapped token]
        controller.addCollateralToken(
            collateralTokens[1],
            _virtualSupplies[1],
            _virtualBalances[1],
            SECONDARY_RESERVE_RATIO,
            _slippages[1],
            0,
            0
        );
        // transfer ADD_COLLATERAL_TOKEN_ROLE
        _transferPermissionFromTemplate(_acl, controller, dandelionVoting, controller.ADD_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
    }


    // App installation functions //

    function _installDandelionVotingApp(Kernel _dao, MiniMeToken _voteToken, uint64[5] _votingSettings)
        internal returns (DandelionVoting)
    {
        DandelionVoting dandelionVoting = DandelionVoting(_installNonDefaultApp(_dao, DANDELION_VOTING_APP_ID));
        dandelionVoting.initialize(_voteToken, _votingSettings[0], _votingSettings[1], _votingSettings[2],
            _votingSettings[3], _votingSettings[4]);
        return dandelionVoting;
    }

    function _installTollgate(Kernel _dao, ERC20 _tollgateFeeToken, uint256 _tollgateFeeAmount, address _tollgateFeeDestination)
        internal returns (ITollgate)
    {
        ITollgate tollgate = ITollgate(_installNonDefaultApp(_dao, TOLLGATE_APP_ID));
        tollgate.initialize(_tollgateFeeToken, _tollgateFeeAmount, _tollgateFeeDestination);
        return tollgate;
    }

    function _installRedemptions(Kernel _dao, Vault _agentOrVault, TokenManager _tokenManager, address[] _redeemableTokens)
        internal returns (Redemptions)
    {
        Redemptions redemptions = Redemptions(_installNonDefaultApp(_dao, REDEMPTIONS_APP_ID));
        redemptions.initialize(_agentOrVault, _tokenManager, _redeemableTokens);
        return redemptions;
    }

    function _installConvictionVoting(Kernel _dao, MiniMeToken _stakeToken, Vault _agentOrVault, address _requestToken)
        internal returns (IConvictionVoting)
    {
        IConvictionVoting convictionVoting = IConvictionVoting(_installNonDefaultApp(_dao, CONVICTION_VOTING_APP_ID));
        convictionVoting.initialize(_stakeToken, _agentOrVault, _requestToken);
        return convictionVoting;
    }

    function _installFundraisingApps(
        uint256 _goal,
        uint64  _period,
        uint256 _exchangeRate,
        uint64  _vestingCliffPeriod,
        uint64  _vestingCompletePeriod,
        uint256 _supplyOfferedPct,
        uint256 _fundingForBeneficiaryPct,
        uint64  _openDate,
        uint256 _batchBlocks,
        uint256 _buyFeePct,
        uint256 _sellFeePct,
        uint256 _maxTapRateIncreasePct,
        uint256 _maxTapFloorDecreasePct,
        address[] _collateralTokens
    )
        internal
    {
        _proxifyFundraisingApps();

        _initializePresale(
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            _collateralTokens
        );
        _initializeMarketMaker(_batchBlocks, _buyFeePct, _sellFeePct);
        _initializeTap(_batchBlocks, _maxTapRateIncreasePct, _maxTapFloorDecreasePct);
        _initializeController(_collateralTokens);
    }

    function _proxifyFundraisingApps() internal {
        (Kernel dao,,,,) = _getDeployedContractsTxOne();

        Vault reserveVault = _installVaultApp(dao);
        Presale presale = Presale(_installNonDefaultApp(dao, PRESALE_ID));
        MarketMaker marketMaker = MarketMaker(_installNonDefaultApp(dao, MARKET_MAKER_ID));
        Tap tap = Tap(_installNonDefaultApp(dao, TAP_ID));
        Controller controller = Controller(_installNonDefaultApp(dao, ARAGON_FUNDRAISING_ID));

        _storeDeployedContractsTxThree(reserveVault, presale, marketMaker, tap, controller);
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
        address[] _collateralTokens
    )
        internal
    {
        // Accessing deployed contracts directly due to stack too deep error.
        senderDeployedContracts[msg.sender].presale.initialize(
            AragonFundraisingController(senderDeployedContracts[msg.sender].controller),
            senderDeployedContracts[msg.sender].tokenManager,
            senderDeployedContracts[msg.sender].reserveVault,
            senderDeployedContracts[msg.sender].fundingPoolVault,
            _collateralTokens[0],
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

    function _initializeMarketMaker(uint256 _batchBlocks, uint256 _buyFeePct, uint256 _sellFeePct) internal {
        IBancorFormula bancorFormula = IBancorFormula(_latestVersionAppBase(BANCOR_FORMULA_ID));

        (,,, Vault beneficiary, TokenManager tokenManager) = _getDeployedContractsTxOne();
        (Vault reserveVault,, MarketMaker marketMaker,, Controller controller) = _getDeployedContractsTxThree();

        marketMaker.initialize(AragonFundraisingController(controller), tokenManager, bancorFormula, reserveVault, beneficiary, _batchBlocks, _buyFeePct, _sellFeePct);
    }

    function _initializeTap(uint256 _batchBlocks, uint256 _maxTapRateIncreasePct, uint256 _maxTapFloorDecreasePct) internal {
        (,,, Vault beneficiary,) = _getDeployedContractsTxOne();
        (Vault reserveVault,,, Tap tap, Controller controller) = _getDeployedContractsTxThree();

        tap.initialize(AragonFundraisingController(controller), reserveVault, beneficiary, _batchBlocks, _maxTapRateIncreasePct, _maxTapFloorDecreasePct);
    }

    function _initializeController(address[] _collateralTokens) internal {
        (Vault reserveVault, Presale presale, MarketMaker marketMaker, Tap tap, Controller controller) = _getDeployedContractsTxThree();
        address[] memory toReset = new address[](1);
        toReset[0] = _collateralTokens[0];
        controller.initialize(presale, marketMaker, reserveVault, tap, toReset);
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

    function _createCustomTokenManagerPermissions() internal {
        (, ACL acl,,,) = _getDeployedContractsTxOne();
        (,, DandelionVoting dandelionVoting,, TokenManager tokenManager) = _getDeployedContractsTxOne();
        (, Presale presale, MarketMaker marketMaker,,) = _getDeployedContractsTxThree();

        address[] memory grantees = new address[](2);
        grantees[0] = address(marketMaker);
        grantees[1] = address(presale);
        acl.createPermission(marketMaker, tokenManager, tokenManager.MINT_ROLE(), dandelionVoting);
        acl.createPermission(presale, tokenManager, tokenManager.ISSUE_ROLE(), dandelionVoting);
        acl.createPermission(presale, tokenManager, tokenManager.ASSIGN_ROLE(), dandelionVoting);
        acl.createPermission(presale, tokenManager, tokenManager.REVOKE_VESTINGS_ROLE(), dandelionVoting);
        _createPermissions(acl, grantees, tokenManager, tokenManager.BURN_ROLE(), dandelionVoting);
    }

    function _createFundraisingPermissions() internal {
        (, ACL acl,,,) = _getDeployedContractsTxOne();
        (,, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();
        (Vault reserveVault, Presale presale, MarketMaker marketMaker, Tap tap, Controller controller) = _getDeployedContractsTxThree();

        // reserveVault
        address[] memory grantees = new address[](2);
        grantees[0] = address(tap);
        grantees[1] = address(marketMaker);
        _createPermissions(acl, grantees, reserveVault, reserveVault.TRANSFER_ROLE(), dandelionVoting);
        // presale
        acl.createPermission(controller, presale, presale.OPEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, presale, presale.CONTRIBUTE_ROLE(), dandelionVoting);
        // market maker
        acl.createPermission(controller, marketMaker, marketMaker.OPEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.UPDATE_BENEFICIARY_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.UPDATE_FEES_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.ADD_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.REMOVE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.UPDATE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.OPEN_BUY_ORDER_ROLE(), dandelionVoting);
        acl.createPermission(controller, marketMaker, marketMaker.OPEN_SELL_ORDER_ROLE(), dandelionVoting);
        // tap
        acl.createPermission(controller, tap, tap.UPDATE_BENEFICIARY_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.UPDATE_MAXIMUM_TAP_RATE_INCREASE_PCT_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.UPDATE_MAXIMUM_TAP_FLOOR_DECREASE_PCT_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.ADD_TAPPED_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.UPDATE_TAPPED_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.RESET_TAPPED_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, tap, tap.WITHDRAW_ROLE(), dandelionVoting);
        // controller
        // ADD_COLLATERAL_TOKEN_ROLE is handled later [after collaterals have been added]
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_BENEFICIARY_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_FEES_ROLE(), dandelionVoting);
        // acl.createPermission(shareVoting, controller, controller.ADD_COLLATERAL_TOKEN_ROLE(), shareVoting);
        acl.createPermission(dandelionVoting, controller, controller.REMOVE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_MAXIMUM_TAP_RATE_INCREASE_PCT_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_MAXIMUM_TAP_FLOOR_DECREASE_PCT_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.ADD_TOKEN_TAP_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_TOKEN_TAP_ROLE(), dandelionVoting);
        acl.createPermission(ANY_ENTITY, controller, controller.OPEN_PRESALE_ROLE(), dandelionVoting);
        acl.createPermission(presale, controller, controller.OPEN_TRADING_ROLE(), dandelionVoting);
        acl.createPermission(address(-1), controller, controller.CONTRIBUTE_ROLE(), dandelionVoting);

        acl.createPermission(ANY_ENTITY, controller, controller.OPEN_BUY_ORDER_ROLE(), dandelionVoting);

        acl.createPermission(ANY_ENTITY, controller, controller.OPEN_SELL_ORDER_ROLE(), address(this));
        _setOracle(acl, ANY_ENTITY, controller, controller.OPEN_SELL_ORDER_ROLE(), dandelionVoting);
        acl.setPermissionManager(dandelionVoting, controller, controller.OPEN_SELL_ORDER_ROLE());

        acl.createPermission(address(-1), controller, controller.WITHDRAW_ROLE(), dandelionVoting);
    }

    // Temporary Storage functions //

    function _storeDeployedContractsTxOne(Kernel _dao, ACL _acl, DandelionVoting _dandelionVoting, Vault _agentOrVault, TokenManager _tokenManager)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.dao = _dao;
        deployedContracts.acl = _acl;
        deployedContracts.dandelionVoting = _dandelionVoting;
        deployedContracts.fundingPoolVault = _agentOrVault;
        deployedContracts.tokenManager = _tokenManager;
    }

    function _getDeployedContractsTxOne() internal returns (Kernel, ACL, DandelionVoting, Vault, TokenManager) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.dao,
            deployedContracts.acl,
            deployedContracts.dandelionVoting,
            deployedContracts.fundingPoolVault,
            deployedContracts.tokenManager
        );
    }

    function _storeDeployedContractsTxThree(Vault _reserve, Presale _presale, MarketMaker _marketMaker, Tap _tap, Controller _controller)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.reserveVault = _reserve;
        deployedContracts.presale = _presale;
        deployedContracts.marketMaker = _marketMaker;
        deployedContracts.tap = _tap;
        deployedContracts.controller = _controller;
    }

    function _getDeployedContractsTxThree() internal returns (Vault, Presale, MarketMaker, Tap, Controller) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.reserveVault,
            deployedContracts.presale,
            deployedContracts.marketMaker,
            deployedContracts.tap,
            deployedContracts.controller
        );
    }

    function _storeCollateralTokens(address[] _collateralTokens) internal {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.collateralTokens = _collateralTokens;
    }

    function _getCollateralTokens() internal returns (address[]) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return deployedContracts.collateralTokens;
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
