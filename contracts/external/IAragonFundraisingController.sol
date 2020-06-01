pragma solidity ^0.4.24;

//import "@ablack/fundraising-batched-bancor-market-maker/contracts/BatchedBancorMarketMaker.sol";
//import "@ablack/fundraising-shared-interfaces/contracts/IPresale.sol";
//import "@ablack/fundraising-shared-interfaces/contracts/ITap.sol";
//import "@aragon/apps-vault/contracts/Vault.sol";

contract IAragonFundraisingController {

    bytes32 public constant UPDATE_FORMULA_ROLE                        = 0xbfb76d8d43f55efe58544ea32af187792a7bdb983850d8fed33478266eec3cbb;
    bytes32 public constant UPDATE_BENEFICIARY_ROLE                    = 0xf7ea2b80c7b6a2cab2c11d2290cb005c3748397358a25e17113658c83b732593;
    bytes32 public constant UPDATE_FEES_ROLE                           = 0x5f9be2932ed3a723f295a763be1804c7ebfd1a41c1348fb8bdf5be1c5cdca822;
    bytes32 public constant ADD_COLLATERAL_TOKEN_ROLE                  = 0x217b79cb2bc7760defc88529853ef81ab33ae5bb315408ce9f5af09c8776662d;
    bytes32 public constant REMOVE_COLLATERAL_TOKEN_ROLE               = 0x2044e56de223845e4be7d0a6f4e9a29b635547f16413a6d1327c58d9db438ee2;
    bytes32 public constant UPDATE_COLLATERAL_TOKEN_ROLE               = 0xe0565c2c43e0d841e206bb36a37f12f22584b4652ccee6f9e0c071b697a2e13d;
    bytes32 public constant OPEN_PRESALE_ROLE                          = 0xf323aa41eef4850a8ae7ebd047d4c89f01ce49c781f3308be67303db9cdd48c2;
    bytes32 public constant OPEN_TRADING_ROLE                          = 0x26ce034204208c0bbca4c8a793d17b99e546009b1dd31d3c1ef761f66372caf6;
    bytes32 public constant CONTRIBUTE_ROLE                            = 0x9ccaca4edf2127f20c425fdd86af1ba178b9e5bee280cd70d88ac5f6874c4f07;
    bytes32 public constant MAKE_BUY_ORDER_ROLE                        = 0x0dfea6908176d96adbee7026b3fe9fbdaccfc17bc443ddf14734fd27c3136179;
    bytes32 public constant MAKE_SELL_ORDER_ROLE                       = 0x52e3ace6a83e0c810920056ccc32fed5aa1e86287545113b03a52ab5c84e3f66;

    function initialize(
        address _presale,
        address _marketMaker,
        address _reserve
    ) external;

    function addCollateralToken(
        address _collateral,
        uint256 _virtualSupply,
        uint256 _virtualBalance,
        uint32  _reserveRatio
    ) external;
}
