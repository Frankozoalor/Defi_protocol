//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
        address public cryptoDevTokenAddress;

        constructor(address _CryptoDevTokens) ERC20("CryptoDev LP Token", "CDLP"){
            require(_CryptoDevTokens != address(0), "Token address passed is a null address");
            cryptoDevTokenAddress = _CryptoDevTokens;
        }

        function getReserve() public view returns(uint) {
            return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
        }

       function addliquidity(uint _amount) public payable returns(uint) {
            uint liquidity;
            uint ethBalance = address(this).balance;
            uint cryptoDevTokenReserve = getReserve();
            ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
    
         if(cryptoDevTokenReserve == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
       } else{
            /*
                If the reserve is not empty, we intake any user supplied value for
                `Ether` and determine according to the ratio how many `Crypto Dev` tokens
                need to be supplied to prevent any large price impacts because of the additional
                liquidity
            */
            // EthReserve is the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint ethReserve = ethBalance - msg.value;
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ratio here is -> (cryptoDevTokenAmount user can add/cryptoDevTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
            // So doing some maths, (cryptoDevTokenAmount user can add) = (Eth Sent by the user * cryptoDevTokenReserve /Eth Reserve);
            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve)/(ethReserve);
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minimum tokens required");
            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);
            // The amount of LP tokens that would be sent to the user should be propotional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is ->
            // (LP tokens to be sent to the user(liquidity)/ totalSupply of LP tokens in contract) = (eth sent by the user)/(eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (eth sent by the user))/(eth reserve in the contract)
            liquidity = (totalSupply() * msg.value)/ ethReserve;
            _mint(msg.sender, liquidity);
        }
           return liquidity;
        }

        function removeLiquidity(uint _amount) public returns(uint,uint){
            require(_amount > 0, "_amount should be greater than zero");
            uint ethReserve = address(this).balance;
            uint _totalSupply = totalSupply();
            // The amount of Eth that would be sent back to the user is based
            // on a ratio
            // Ratio is -> (Eth sent back to the user/ Current Eth reserve)
            // = (amount of LP tokens that user wants to withdraw)/ Total supply of `LP` tokens
            // Then by some maths -> (Eth sent back to the user)
            // = (Current Eth reserve * amount of LP tokens that user wants to withdraw)/Total supply of `LP` tokens
            uint ethAmount = (ethReserve * _amount)/ _totalSupply;
            uint cryptoDevTokenAmount = (getReserve() * _amount)/_totalSupply;
            // Burn the sent `LP` tokens from the user'a wallet because they are already sent to
            // remove liquidity
            _burn(msg.sender, _amount);
            // Transfer `ethAmount` of Eth from user's wallet to the contract
            payable(msg.sender).transfer(ethAmount);
            // Transfer `cryptoDevTokenAmount` of `Crypto Dev` tokens from the user's wallet to the contract
            ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
            return (ethAmount, cryptoDevTokenAmount);
    }

         function getAmountOfTokens(
            uint256 inputAmount,
            uint256 inputReserve,
            uint256 outputReserve
        ) public pure returns(uint256) {
            require(inputReserve > 0 && outputReserve > 0, "invalid reserve");
            // We are charging a fees of `1%`
            // Input amount with fees = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
            uint256 inputAmountWithFee = inputAmount * 99;
            // Because we need to follow the concept of `XY = K` curve
            // We need to make sure (x + Δx)*(y - Δy) = (x)*(y)
            // so the final formulae is Δy = (y*Δx)/(x + Δx);
            // Δy in our case is `tokens to be recieved`
            // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
            // So by putting the values in the formulae you can get the numerator and denominator
            uint256 numerator = inputAmountWithFee * outputReserve;
            uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
            return numerator / denominator;
    }
          //function swapping eth to cryptoDevToken
           function ethToCryptoDevToken(uint _minTokens) public payable {
            uint256 tokenReserve = getReserve();
            // we call the `getAmountOfTokens` to get the amount of crypto dev tokens
            // that would be returned to the user after the swap
            // the `inputReserve` we are sending is equal to
            //  `address(this).balance - msg.value` instead of just `address(this).balance`
            // because `address(this).balance` already contains the `msg.value` user has sent in the given call
            // so we need to subtract it to get the actual input reserve
            uint256 tokensBought = getAmountOfTokens(
                msg.value, address(this).balance - msg.value,
                tokenReserve
            );
            require(tokensBought >= _minTokens, "insufficent output amount");
            //Transfer the 'Crypto Dev' tokens to the user
            ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
       }

         // function swapping cryptoDevTokens to Eth
         function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
            uint256 tokenReserve = getReserve();
            // we call the `getAmountOfTokens` to get the amount of ether
            // that would be returned to the user after the swap
            uint256 ethBought = getAmountOfTokens(
                _tokensSold,
                tokenReserve,
                address(this).balance
            );
            require(ethBought >= _minEth, "insufficent output amount");
            ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
            // send the `ethBought` to the user from the contract
            payable(msg.sender).transfer(ethBought);
      } 


}