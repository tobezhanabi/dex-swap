// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
  address public cryptoDevTokenAddress;

  constructor(address _CryptoDevToken) ERC20("CeyptoDev Lp Token", "CDLP") {
    require(
      _CryptoDevToken != address(0),
      "Token address passed is a null address"
    );
    cryptoDevTokenAddress = _CryptoDevToken;
  }

  /**
   *  @dev Returns the amount of `crypto dev token` held by the contract
   */
  function getReserve() public view returns (uint) {
    return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
  }

  /**
   * @dev adds liquidity to the contract exechange
   */

  function addLiquidity(uint _amount) public payable returns (uint) {
    uint liquidity;
    uint ethBalance = address(this).balance;
    uint cryptoDevTokenReserve = getReserve();
    ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
    // when the reserve is empty ut takes any amount of eth and crypto dev token
    // because there is no ratio yet

    if (cryptoDevTokenReserve == 0) {
      // Transfer the `cryptoDevToken` from the user's account to the contract
      cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
      liquidity = ethBalance;
      _mint(msg.sender, liquidity);
      // so bcos reserve is zero and this is the first liquidity add. the lp is equal to the ETH added
    } else {
      /*
            If the reserve is not empty, intake any user supplied value for
            `Ether` and determine according to the ratio how many `Crypto Dev` tokens
            need to be supplied to prevent any large price impacts because of the additional
            liquidity
        */
      uint ethReserve = ethBalance - msg.value;
      // Ratio should always be maintained so that there are no major price impacts when adding liquidity
      // Ratio here is -> (cryptoDevTokenAmount user can add/cryptoDevTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
      // So doing some maths, (cryptoDevTokenAmount user can add) = (Eth Sent by the user * cryptoDevTokenReserve /Eth Reserve);
      uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) /
        (ethReserve);
      require(
        _amount >= cryptoDevTokenAmount,
        "Amount of Tokens sent is less than the min required"
      );
      cryptoDevToken.transferFrom(
        msg.sender,
        address(this),
        cryptoDevTokenAmount
      );
      liquidity = (totalSupply() * msg.value) / ethReserve;
      _mint(msg.sender, liquidity);
    }
    return liquidity;
  }

  /**
   * @dev  returns the amount of cryptodev Tokens / eth that would be returned to the user in the swap
   */
  function removeLiquidity(uint _amount) public returns (uint, uint) {
    require(_amount > 0, "amount should be greater than zero");
    uint ethReserve = address(this).balance;
    uint _totalSupply = totalSupply();
    uint ethAmount = (ethReserve * _amount) / _totalSupply;
    uint cryptoDevTokenAmount = (getReserve() * _amount) / _totalSupply;
    // Burn the sent LP tokens from the user's wallet because they are already sent to
    // remove liquidity
    _burn(msg.sender, _amount);
    // Transfer `ethAmount` of Eth from the contract to the user's wallet
    payable(msg.sender).transfer(ethAmount);
    // Transfer `cryptoDevTokenAmount` of Crypto Dev tokens from the contract to the user's wallet
    ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
    return (ethAmount, cryptoDevTokenAmount);
  }

  function getAmountOfTokens(
    uint256 inputAmount,
    uint256 inputReserve,
    uint256 outputReserve
  ) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
    // We are charging a fee of `1%`
    // Input amount with fee = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100

    uint256 inputAmountWithFee = inputAmount * 99;
    // Because we need to follow the concept of `XY = K` curve
    // We need to make sure (x + Δx) * (y - Δy) = x * y
    // So the final formula is Δy = (y * Δx) / (x + Δx)
    // Δy in our case is `tokens to be received`
    // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
    // So by putting the values in the formulae you can get the numerator and denominator

    uint256 numerator = inputAmountWithFee * outputReserve;
    uint256 denominator = (inputReserve * 100) + inputAmount;
    return numerator / denominator;
  }

  /**
   * @dev swap ETH for CryptoDev Token
   *
   */

  function ethToCryptoDevToken(uint _minTokens) public payable {
    uint256 tokenReserve = getReserve();
    // call the getAmount function to get amount of cryptodev Tokens
    uint256 tokensBought = getAmountOfTokens(
      msg.value,
      // Notice that the `inputReserve` we are sending is equal to
      // `address(this).balance - msg.value` instead of just `address(this).balance`
      // because `address(this).balance` already contains the `msg.value` user has sent in the given call
      // so we need to subtract it to get the actual input reserve
      address(this).balance - msg.value,
      tokenReserve
    );
    require(tokensBought >= _minTokens, "insufficient Output Amount");
    // Transfer the `Crypto Dev` tokens to the user
    ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
  }

  function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmountOfTokens(
      _tokensSold,
      tokenReserve,
      address(this).balance
    );
    require(ethBought > _minEth, "insufficient output amount");

    ERC20(cryptoDevTokenAddress).transferFrom(
      msg.sender,
      address(this),
      _tokensSold
    );

    payable(msg.sender).transfer(ethBought);
  }
}
