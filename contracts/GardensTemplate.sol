pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-dandelion-voting/contracts/DandelionVoting.sol";
import "@1hive/apps-redemptions/contracts/Redemptions.sol";
import "@1hive/apps-token-manager/contracts/HookedTokenManager.sol";
import "@ablack/fundraising-bancor-formula/contracts/BancorFormula.sol";
import "@ablack/fundraising-aragon-fundraising/contracts/AragonFundraisingController.sol";
import "@ablack/fundraising-presale/contracts/Presale.sol";
import {IConvictionVoting as ConvictionVoting} from "./external/IConvictionVoting.sol";
import {ITollgate as Tollgate} from "./external/ITollgate.sol";
import {IBancorMarketMaker as MarketMaker} from "./external/IBancorMarketMaker.sol";
import {IAragonFundraisingController as Controller} from "./external/IAragonFundraisingController.sol";

contract GardensTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MISSING_MEMBERS";
    string constant private ERROR_BAD_VOTE_SETTINGS = "BAD_SETTINGS";
    string constant private ERROR_NO_CACHE = "NO_CACHE";
    string constant private ERROR_NO_COLLATERAL = "NO_COLLATERAL";
    string constant private ERROR_NO_TOLLGATE_TOKEN = "NO_TOLLGATE_TOKEN";

    /**
    * bytes32 private constant DANDELION_VOTING_APP_ID = apmNamehash("dandelion-voting");
    * bytes32 private constant REDEMPTIONS_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("redemptions")));
    * bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("conviction-voting")));
    * bytes32 private constant TOLLGATE_APP_ID = apmNamehash("tollgate");
    * bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("hooked-token-manager")));
    * bytes32 private constant BANCOR_FORMULA_ID = apmNamehash("bancor-formula");
    * bytes32 private constant PRESALE_ID = apmNamehash("presale");
    * bytes32 private constant MARKET_MAKER_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("bancor-market-maker")));
    * bytes32 private constant MARKETPLACE_CONTROLLER_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("marketplace-controller")));
    */
    // Local app ID's
    bytes32 private constant DANDELION_VOTING_APP_ID = 0x2d7442e1c4cb7a7013aecc419f938bdfa55ad32d90002fb92ee5969e27b2bf07;
    bytes32 private constant REDEMPTIONS_APP_ID = 0xbf9fefd9508fe20f068aa3714e9beb8c4fc6dea33dc4c75371b96140d6350d20;
    bytes32 private constant CONVICTION_VOTING_APP_ID = 0x589851b3734f6578a92f33bfc26877a1166b95238be1f484deeaac6383d14c38;
    bytes32 private constant TOLLGATE_APP_ID = 0x7075e547e73484f0736b2160fcfb010b4f32b751fc729c25b677a0347d9b4246;
    bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = 0xb2d2065b829a91588c8b9a15d99acd026f6673733603c6c60e505654eb2b472d;

    // Rinkeby app ID's
//        bytes32 private constant DANDELION_VOTING_APP_ID = 0x40a80c4b4050993512df39c802adec62dafeb1f0586cc15f4d34bda9c47ba468; // gardens-dandelion-voting.open.aragonpm.eth
//        bytes32 private constant REDEMPTIONS_APP_ID = 0x743bd419d5c9061290b181b19e114f36e9cc9ddb42b4e54fc811edb22eb85e9d;
//        bytes32 private constant TOLLGATE_APP_ID = 0x0d321283289e70165ef6db7f11fc62c74a7d39dac3ee148428c4f9e3d74c6d61; // tollgate.open.aragonpm.eth
//        bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = 0x26bb91b115bf14acbdc18d75042e165321eceeb3d10d852386576bbd0ec11519; // gardens-token-manager.open.aragonpm.eth

    //    bytes32 private constant CONVICTION_VOTING_APP_ID = 0xc5e2e4d7422daecfc2dc08a9932e5b9f84cf5b2f61a81ef13e257b4803b93b2f; // gardens-conviction-voting.open.aragonpm.eth
//        bytes32 private constant CONVICTION_VOTING_APP_ID = 0x2e20d4e6af7ec3f285a8c7358e357d14483ccf38e79779c3037bc70c24141038; // conviction-voting-gardens.open.aragonpm.eth

    // Local and Rinkeby app ID's (no need to change between environments)
    bytes32 private constant BANCOR_FORMULA_ID = 0xd71dde5e4bea1928026c1779bde7ed27bd7ef3d0ce9802e4117631eb6fa4ed7d;
    bytes32 private constant PRESALE_ID = 0x5de9bbdeaf6584c220c7b7f1922383bcd8bbcd4b48832080afd9d5ebf9a04df5;
    bytes32 private constant MARKET_MAKER_ID = 0x082190c7d2371cc21a38fcd9c3cd724dd686e838e1f7a435f9f5fbc0cb562f0f; // bancor-market-maker.open.aragonpm.eth
    bytes32 private constant MARKETPLACE_CONTROLLER_ID = 0x11a4d82f2764c41dac72ca406a52a7392a0800047a040944b29dccd669bad8e9; // marketplace-controller.open.aragonpm.eth

    bool private constant TOKEN_TRANSFERABLE = true;
    uint8 private constant TOKEN_DECIMALS = uint8(18);
    uint256 private constant TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    uint64 private constant DEFAULT_FINANCE_PERIOD = uint64(30 days);
    address private constant ANY_ENTITY = address(-1);
    uint8 private constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }

    struct DeployedContracts {
        Kernel dao;
        ACL acl;
        DandelionVoting dandelionVoting;
        Vault fundingPoolVault;
        HookedTokenManager hookedTokenManager;
        address collateralToken;
        Vault reserveVault;
        Presale presale;
        MarketMaker marketMaker;
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

    /**
    * @dev Create the DAO and initialise the basic apps necessary for gardens
    * @param _voteTokenName The name for the token used by share holders in the organization
    * @param _voteTokenSymbol The symbol for the token used by share holders in the organization
    * @param _votingSettings Array of [supportRequired, minAcceptanceQuorum, voteDuration, voteBufferBlocks, voteExecutionDelayBlocks] to set up the voting app of the organization
    * @param _useAgentAsVault Whether to use an Agent app or Vault app
    */
    function createDaoTxOne(
        string _voteTokenName,
        string _voteTokenSymbol,
        uint64[5] _votingSettings,
        bool _useAgentAsVault
    )
        public
    {
        require(_votingSettings.length == 5, ERROR_BAD_VOTE_SETTINGS);

        (Kernel dao, ACL acl) = _createDAO();
        MiniMeToken voteToken = _createToken(_voteTokenName, _voteTokenSymbol, TOKEN_DECIMALS);
        Vault fundingPoolVault = _useAgentAsVault ? _installDefaultAgentApp(dao) : _installVaultApp(dao);
        DandelionVoting dandelionVoting = _installDandelionVotingApp(dao, voteToken, _votingSettings);
        HookedTokenManager hookedTokenManager = _installHookedTokenManagerApp(dao, voteToken, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);

        if (_useAgentAsVault) {
            _createAgentPermissions(acl, Agent(fundingPoolVault), dandelionVoting, dandelionVoting);
        }
        _createEvmScriptsRegistryPermissions(acl, dandelionVoting, dandelionVoting);
        _createCustomVotingPermissions(acl, dandelionVoting, hookedTokenManager);

        _storeDeployedContractsTxOne(dao, acl, dandelionVoting, fundingPoolVault, hookedTokenManager);
    }

    /**
    * @dev Add and initialise tollgate, redemptions and conviction voting or finance apps
    * @param _tollgateFeeToken The token used to pay the tollgate fee
    * @param _tollgateFeeAmount The tollgate fee amount
    * @param _redeemableTokens Array of initially redeemable tokens
    * @param _useConvictionAsFinance Whether to use conviction voting or finance
    * @param _financePeriod Finance period
    * @param _collateralToken Token distributed by conviction voting and used as collateral in fundraising
    */
    function createDaoTxTwo(
        ERC20 _tollgateFeeToken,
        uint256 _tollgateFeeAmount,
        address[] _redeemableTokens,
        bool _useConvictionAsFinance,
        uint64 _financePeriod,
        address _collateralToken
    )
        public
    {
        require(_tollgateFeeToken != address(0), ERROR_NO_TOLLGATE_TOKEN);
        require(_collateralToken != address(0), ERROR_NO_COLLATERAL);
        require(senderDeployedContracts[msg.sender].dao != address(0), ERROR_NO_CACHE);

        (,
        ACL acl,
        DandelionVoting dandelionVoting,
        Vault fundingPoolVault,
        HookedTokenManager hookedTokenManager) = _getDeployedContractsTxOne();

        Tollgate tollgate = _installTollgate(senderDeployedContracts[msg.sender].dao, _tollgateFeeToken, _tollgateFeeAmount, address(fundingPoolVault));
        _createTollgatePermissions(acl, tollgate, dandelionVoting);

        Redemptions redemptions = _installRedemptions(senderDeployedContracts[msg.sender].dao, fundingPoolVault, hookedTokenManager, _redeemableTokens);
        _createRedemptionsPermissions(acl, redemptions, dandelionVoting);

        if (_useConvictionAsFinance) {
            ConvictionVoting convictionVoting = _installConvictionVoting(senderDeployedContracts[msg.sender].dao, hookedTokenManager.token(), fundingPoolVault, _collateralToken);
            _createVaultPermissions(acl, fundingPoolVault, convictionVoting, dandelionVoting);
            _createConvictionVotingPermissions(acl, convictionVoting, dandelionVoting);

            _createPermissionForTemplate(acl, hookedTokenManager, hookedTokenManager.SET_HOOK_ROLE());
            hookedTokenManager.registerHook(convictionVoting);
            hookedTokenManager.registerHook(dandelionVoting);
            _removePermissionFromTemplate(acl, hookedTokenManager, hookedTokenManager.SET_HOOK_ROLE());
        } else {
            Finance finance = _installFinanceApp(senderDeployedContracts[msg.sender].dao, fundingPoolVault, _financePeriod == 0 ? DEFAULT_FINANCE_PERIOD : _financePeriod);
            _createVaultPermissions(acl, fundingPoolVault, finance, dandelionVoting);
            _createFinancePermissions(acl, finance, dandelionVoting, dandelionVoting);
        }

        _storeDeployedContractsTxTwo(_collateralToken);
    }

    /**
    * @dev Add and initialise fundraising apps
    * @param _goal Presale goal in wei
    * @param _period Presale length in seconds
    * @param _exchangeRate Presale exchange rate in PPM
    * @param _vestingCliffPeriod Vesting cliff length for presale bought tokens in seconds
    * @param _vestingCompletePeriod Vesting complete length for presale bought tokens in seconds
    * @param _supplyOfferedPct Percent of total supply offered in presale in PPM
    * @param _fundingForBeneficiaryPct Percent of raised presale funds sent to the organization in PPM
    * @param _openDate The time the presale starts, requires manual opening if set to 0
    * @param _buyFeePct The Percent of a purchase contribution that is sent to the organization in PCT_BASE
    * @param _sellFeePct The percent of a sale return that is sent to the organization in PCT_BASE
    */
    function createDaoTxThree(
        uint256 _goal,
        uint64 _period,
        uint256 _exchangeRate,
        uint64 _vestingCliffPeriod,
        uint64 _vestingCompletePeriod,
        uint256 _supplyOfferedPct,
        uint256 _fundingForBeneficiaryPct,
        uint64 _openDate,
        uint256 _buyFeePct,
        uint256 _sellFeePct
    )
        public
    {
        require(senderDeployedContracts[msg.sender].collateralToken != address(0), ERROR_NO_CACHE);

        _installFundraisingApps(
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            _buyFeePct,
            _sellFeePct
        );

        _createHookedTokenManagerPermissions();
        _createFundraisingPermissions();
    }

    /**
    * @dev Configure the fundraising collateral and finalise permissions
    * @param _id Unique Aragon DAO ID
    * @param _virtualSupply Collateral token virtual supply in wei
    * @param _virtualBalance Collateral token virtual balance in wei
    * @param _reserveRatio The reserve ratio to be used for the collateral token in PPM
    */
    function createDaoTxFour(
        string _id,
        uint256 _virtualSupply,
        uint256 _virtualBalance,
        uint32 _reserveRatio
    )
        public
    {
        require(senderDeployedContracts[msg.sender].reserveVault != address(0), ERROR_NO_CACHE);

        _validateId(_id);
        (Kernel dao, ACL acl, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();

        _setupCollateralToken(dao, acl, _virtualSupply, _virtualBalance, _reserveRatio);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, dandelionVoting);
        _registerID(_id, dao);
        _deleteStoredContracts();
    }

    // App installation/setup functions //

    function _installHookedTokenManagerApp(
        Kernel _dao,
        MiniMeToken _token,
        bool _transferable,
        uint256 _maxAccountTokens
    )
        internal returns (HookedTokenManager)
    {
        HookedTokenManager hookedTokenManager = HookedTokenManager(_installDefaultApp(_dao, HOOKED_TOKEN_MANAGER_APP_ID));
        _token.changeController(hookedTokenManager);
        hookedTokenManager.initialize(_token, _transferable, _maxAccountTokens);
        return hookedTokenManager;
    }

    function _installDandelionVotingApp(Kernel _dao, MiniMeToken _voteToken, uint64[5] _votingSettings)
        internal returns (DandelionVoting)
    {
        DandelionVoting dandelionVoting = DandelionVoting(_installNonDefaultApp(_dao, DANDELION_VOTING_APP_ID));
        dandelionVoting.initialize(_voteToken, _votingSettings[0], _votingSettings[1], _votingSettings[2],
            _votingSettings[3], _votingSettings[4]);
        return dandelionVoting;
    }

    function _installTollgate(Kernel _dao, ERC20 _tollgateFeeToken, uint256 _tollgateFeeAmount, address _tollgateFeeDestination)
        internal returns (Tollgate)
    {
        Tollgate tollgate = Tollgate(_installNonDefaultApp(_dao, TOLLGATE_APP_ID));
        tollgate.initialize(_tollgateFeeToken, _tollgateFeeAmount, _tollgateFeeDestination);
        return tollgate;
    }

    function _installRedemptions(Kernel _dao, Vault _agentOrVault, HookedTokenManager _hookedTokenManager, address[] _redeemableTokens)
        internal returns (Redemptions)
    {
        Redemptions redemptions = Redemptions(_installNonDefaultApp(_dao, REDEMPTIONS_APP_ID));
        redemptions.initialize(_agentOrVault, TokenManager(_hookedTokenManager), _redeemableTokens);
        return redemptions;
    }

    function _installConvictionVoting(Kernel _dao, MiniMeToken _stakeToken, Vault _agentOrVault, address _requestToken)
        internal returns (ConvictionVoting)
    {
        ConvictionVoting convictionVoting = ConvictionVoting(_installNonDefaultApp(_dao, CONVICTION_VOTING_APP_ID));
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
        uint256 _buyFeePct,
        uint256 _sellFeePct
    )
        internal
    {
        _proxifyFundraisingApps();
        address collateralToken = _getDeployedContractsTxTwo();

        _initializePresale(
            _goal,
            _period,
            _exchangeRate,
            _vestingCliffPeriod,
            _vestingCompletePeriod,
            _supplyOfferedPct,
            _fundingForBeneficiaryPct,
            _openDate,
            collateralToken
        );
        _initializeMarketMaker(_buyFeePct, _sellFeePct);
        _initializeController(collateralToken);
    }

    function _proxifyFundraisingApps() internal {
        (Kernel dao,,,,) = _getDeployedContractsTxOne();

        Vault reserveVault = _installVaultApp(dao);
        Presale presale = Presale(_installNonDefaultApp(dao, PRESALE_ID));
        MarketMaker marketMaker = MarketMaker(_installNonDefaultApp(dao, MARKET_MAKER_ID));
        Controller controller = Controller(_installNonDefaultApp(dao, MARKETPLACE_CONTROLLER_ID));

        _storeDeployedContractsTxThree(reserveVault, presale, marketMaker, controller);
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
        address _collateralToken
    )
        internal
    {
        // Accessing deployed contracts directly due to stack too deep error.
        senderDeployedContracts[msg.sender].presale.initialize(
            AragonFundraisingController(senderDeployedContracts[msg.sender].controller),
            TokenManager(senderDeployedContracts[msg.sender].hookedTokenManager),
            senderDeployedContracts[msg.sender].reserveVault,
            senderDeployedContracts[msg.sender].fundingPoolVault,
            _collateralToken,
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

    function _initializeMarketMaker(uint256 _buyFeePct, uint256 _sellFeePct) internal {
        IBancorFormula bancorFormula = IBancorFormula(_latestVersionAppBase(BANCOR_FORMULA_ID));

        (,,, Vault beneficiary, HookedTokenManager hookedTokenManager) = _getDeployedContractsTxOne();
        (Vault reserveVault,, MarketMaker marketMaker, Controller controller) = _getDeployedContractsTxThree();

        marketMaker.initialize(AragonFundraisingController(controller), TokenManager(hookedTokenManager), bancorFormula, reserveVault, beneficiary, _buyFeePct, _sellFeePct);
    }

    function _initializeController(address _collateralToken) internal {
        (Vault reserveVault, Presale presale, MarketMaker marketMaker, Controller controller) = _getDeployedContractsTxThree();
        controller.initialize(presale, marketMaker, reserveVault);
    }

    function _setupCollateralToken(
        Kernel _dao,
        ACL _acl,
        uint256 _virtualSupply,
        uint256 _virtualBalance,
        uint32 _reserveRatio
    )
    internal
    {
        (,, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();
        (,,, Controller controller) = _getDeployedContractsTxThree();
        address collateralToken = _getDeployedContractsTxTwo();

        _createPermissionForTemplate(_acl, address(controller), controller.ADD_COLLATERAL_TOKEN_ROLE());
        controller.addCollateralToken(
            collateralToken,
            _virtualSupply,
            _virtualBalance,
            _reserveRatio
        );
        _transferPermissionFromTemplate(_acl, controller, dandelionVoting, controller.ADD_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
    }

    // Permission setting functions //

    function _createCustomVotingPermissions(ACL _acl, DandelionVoting _dandelionVoting, HookedTokenManager _hookedTokenManager)
        internal
    {
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_QUORUM_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_SUPPORT_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_BUFFER_BLOCKS_ROLE(), _dandelionVoting);
        _acl.createPermission(_dandelionVoting, _dandelionVoting, _dandelionVoting.MODIFY_EXECUTION_DELAY_ROLE(), _dandelionVoting);
    }

    function _createTollgatePermissions(ACL _acl, Tollgate _tollgate, DandelionVoting _dandelionVoting) internal {
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

    function _createConvictionVotingPermissions(ACL _acl, ConvictionVoting _convictionVoting, DandelionVoting _dandelionVoting)
        internal
    {
        _acl.createPermission(ANY_ENTITY, _convictionVoting, _convictionVoting.CREATE_PROPOSALS_ROLE(), _dandelionVoting);
    }

    function _createHookedTokenManagerPermissions() internal {
        (, ACL acl,,,) = _getDeployedContractsTxOne();
        (,, DandelionVoting dandelionVoting,, HookedTokenManager hookedTokenManager) = _getDeployedContractsTxOne();
        (, Presale presale, MarketMaker marketMaker,) = _getDeployedContractsTxThree();

        address[] memory grantees = new address[](2);
        grantees[0] = address(marketMaker);
        grantees[1] = address(presale);
        acl.createPermission(marketMaker, hookedTokenManager, hookedTokenManager.MINT_ROLE(), dandelionVoting);
        acl.createPermission(presale, hookedTokenManager, hookedTokenManager.ISSUE_ROLE(), dandelionVoting);
        acl.createPermission(presale, hookedTokenManager, hookedTokenManager.ASSIGN_ROLE(), dandelionVoting);
        acl.createPermission(presale, hookedTokenManager, hookedTokenManager.REVOKE_VESTINGS_ROLE(), dandelionVoting);
        _createPermissions(acl, grantees, hookedTokenManager, hookedTokenManager.BURN_ROLE(), dandelionVoting);
    }

    function _createFundraisingPermissions() internal {
        (, ACL acl,,,) = _getDeployedContractsTxOne();
        (,, DandelionVoting dandelionVoting,,) = _getDeployedContractsTxOne();
        (Vault reserveVault, Presale presale, MarketMaker marketMaker, Controller controller) = _getDeployedContractsTxThree();

        // reserveVault
        acl.createPermission(marketMaker, reserveVault, reserveVault.TRANSFER_ROLE(), dandelionVoting);
        // presale
        acl.createPermission(controller, presale, presale.OPEN_ROLE(), dandelionVoting);
        acl.createPermission(controller, presale, presale.CONTRIBUTE_ROLE(), dandelionVoting);
        // market maker
        acl.createPermission(controller, marketMaker, marketMaker.CONTROLLER_ROLE(), dandelionVoting);
        // controller
        // ADD_COLLATERAL_TOKEN_ROLE is handled later [after collaterals have been added]
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_BENEFICIARY_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_FEES_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.REMOVE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(dandelionVoting, controller, controller.UPDATE_COLLATERAL_TOKEN_ROLE(), dandelionVoting);
        acl.createPermission(ANY_ENTITY, controller, controller.OPEN_PRESALE_ROLE(), dandelionVoting);
        acl.createPermission(presale, controller, controller.OPEN_TRADING_ROLE(), dandelionVoting);
        acl.createPermission(ANY_ENTITY, controller, controller.CONTRIBUTE_ROLE(), dandelionVoting);
        acl.createPermission(ANY_ENTITY, controller, controller.MAKE_BUY_ORDER_ROLE(), dandelionVoting);
        acl.createPermission(ANY_ENTITY, controller, controller.MAKE_SELL_ORDER_ROLE(), address(this));
        _setOracle(acl, ANY_ENTITY, controller, controller.MAKE_SELL_ORDER_ROLE(), dandelionVoting);
        acl.setPermissionManager(dandelionVoting, controller, controller.MAKE_SELL_ORDER_ROLE());
    }

    // Temporary Storage functions //

    function _storeDeployedContractsTxOne(Kernel _dao, ACL _acl, DandelionVoting _dandelionVoting, Vault _agentOrVault, HookedTokenManager _hookedTokenManager)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.dao = _dao;
        deployedContracts.acl = _acl;
        deployedContracts.dandelionVoting = _dandelionVoting;
        deployedContracts.fundingPoolVault = _agentOrVault;
        deployedContracts.hookedTokenManager = _hookedTokenManager;
    }

    function _getDeployedContractsTxOne() internal returns (Kernel, ACL, DandelionVoting, Vault, HookedTokenManager) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.dao,
            deployedContracts.acl,
            deployedContracts.dandelionVoting,
            deployedContracts.fundingPoolVault,
            deployedContracts.hookedTokenManager
        );
    }

    function _storeDeployedContractsTxTwo(address _collateralToken) internal {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.collateralToken = _collateralToken;
    }

    function _getDeployedContractsTxTwo() internal returns (address) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return deployedContracts.collateralToken;
    }

    function _storeDeployedContractsTxThree(Vault _reserve, Presale _presale, MarketMaker _marketMaker, Controller _controller)
        internal
    {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        deployedContracts.reserveVault = _reserve;
        deployedContracts.presale = _presale;
        deployedContracts.marketMaker = _marketMaker;
        deployedContracts.controller = _controller;
    }

    function _getDeployedContractsTxThree() internal returns (Vault, Presale, MarketMaker, Controller) {
        DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
        return (
            deployedContracts.reserveVault,
            deployedContracts.presale,
            deployedContracts.marketMaker,
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
