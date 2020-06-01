pragma solidity ^0.4.24;

contract IBancorMarketMaker {

    bytes32 public constant CONTROLLER_ROLE = 0x7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357;

    function initialize(
        address _controller,
        address _tokenManager,
        address _formula,
        address _reserve,
        address _beneficiary,
        uint256 _buyFeePct,
        uint256 _sellFeePct
    );
}
