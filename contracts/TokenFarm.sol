// SPDX-License-Identifer: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {

    mapping(address => mapping(address => uint256)) public stakingBalance; // token address -> staker address -> amount
    mapping(address => uint256) public uniqueTokensStaked; // how many different tokens each of the addresses has staked
    mapping(address => address) public tokenPriceFeed; // price feeds for allowed tokens
    address[] public stakers; // all current stakers
    address[] public allowedTokens; // all currently allowed tokens
    IERC20 public dappToken;

    constructor(address _dappToken) public {
        dappToken = IERC20(_dappToken);
    }

    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeed[_token] = _priceFeed;
    }

    /*
        stakeTokens - ability to add tokens in the platform
    */
    function stakeToken(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(isTokenAllowed(_token), "Token is currently now allowed");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokenStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] = stakingBalance[_token][msg.sender] + _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;

    }

    function updateUniqueTokenStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    /*
        add allowed tokens
    */
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function isTokenAllowed(address _token) public returns (bool) {
        for (uint256 allowedTokensIndex = 0; allowedTokensIndex < allowedTokens.length; ++allowedTokensIndex) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }

    /* 
        issueTokens - reward given to users for using the platform, based off value of underlying token that they have staked
    */
    function issueTokens() public onlyOwner {
        for (uint256 stakersIndex = 0; stakersIndex < stakers.length; ++stakersIndex) {
            address recipient = stakers[stakersIndex];
            // send them a token reward based on their total value staked
            uint256 userTotalValue = getUserTotalValue(recipient);
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    function getUserTotalValue(address _user) public view returns(uint256) {
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        uint256 totalValue = 0;
        for (uint256 allowedTokensIndex = 0; allowedTokensIndex < allowedTokens.length; ++allowedTokensIndex) {
            totalValue = totalValue + getUserSingleTokenValue(_user, allowedTokens[allowedTokensIndex]);
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token) public view returns(uint256) {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        // price of the token * stakingBalance[_token][_user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return (stakingBalance[_token][_user] * price / (10**decimals));
    }

    /*
        getValue
    */
    function getTokenValue(address _token) public view returns(uint256, uint256) {
        // priceFeedAddress
        address priceFeedAddress = tokenPriceFeed[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price), decimals);
    }

}