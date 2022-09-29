// SPDX-License-Identifier: MIT

/**
 *
 *                  @@@@@@@@@@@@@@@@@*.         #@@@@#-         %@@%.             @@@%      
 *                  @@@@=---------=@@@@.      .%@@+@@@@*        %@@@:             @@@@.     
 *                  @@@@=---------=@@@@.     -@@%: .%@@@%.      %@@@:             @@@@.     
 *                  @@@@%%%%%%%%%%@@@@%:    +@@#     #@@@@:     %@@@:             @@@@.     
 *                  @@@@.          -@@@%   #@@+       +@@@@=    %@@@:             @@@@.     
 *                  @@@@+++++++++++%@@@+ .%@@-    =****%@@@@*   %@@@#**********=  @@@@.     
 *                  %%%%%%%%%%%%%%%%#+: :#%#:    +%%%%%%%%%%%*  *%%%%%%%%%%%%%#:  =#%%.     
 *
 *          ==================:  ====:  :============:    .===  ===-    ======:          .==
 *          *@@@@@@@@@@@@@@@@@@= -@@@@*  =@@@@@@@@@@+    -@@%:  %@@@:  .@@@@@@@%-        %@@
 *                  @@@@.         .%@@@%. :@@@@*        +@@#    %@@@:  .@@%:#@@@@%-      %@@
 *                  @@@@.           *@@@@- .%@@@%.     #@@+     %@@@:  .@@%  :#@@@@%-    %@@
 *                  @@@@.            =@@@@+  *@@@@-  .%@@-      %@@@:  .@@%    :#@@@@#:  %@@
 *                  @@@@.             -@@@@*  =@@@@+-@@%:       %@@@:  .@@%      :#@@@@#:%@@
 *                  @@@@.              .%@@@%. -@@@@@@#         #@@@:   @@%        :#@@@@@@@
 *
 */

pragma solidity ^0.8.15;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

interface ERC20 is IERC20 {
	function mint (address to, uint amount) external;
	function burnFrom (address account, uint amount) external;
}

interface ERC721 is IERC721 {
	function mint (address to, uint id, bytes memory data) external;
	function burn (uint id) external;
}

interface ERC1155 is IERC1155 {
	function mint (address to, uint id, uint amount, bytes memory data) external;
	function mintBatch (address to, uint[] memory ids, uint[] memory amounts, bytes memory data) external;

	function burn (address account, uint id, uint amount) external;
	function burnBatch (address account, uint[] memory ids, uint[] memory amounts) external;
}

/// @title Forge
/// @author BaliTwin Developers
/// @notice Forge is a contract that allows you to craft Tokens from other Tokens

/// @custom:version 1.0.0
/// @custom:website https://balitwin.com
/// @custom:security-contact security@balitwin.com

contract BaliTwinForge is Ownable { 
	using Counters for Counters.Counter;
	
	/// @notice Token requirements for crafting
	struct IO {
		address token;
		uint[] ids;
		uint[] amounts;
	}

	/** @notice Crafting recipe
	 * 
	 *  @param input Input ERC20, ERC721, ERC1155 token or network native token
	 *  @param output Output ERC20, ERC721, ERC1155 token or network native token
	 * 
	 *  @param limit Maximum number of times this recipe can be used
	 *  @param count Number of times this recipe has been used
	 * 
	 *  @param fee Fee to be paid for using this recipe
	 */

	struct Recipe {
		IO input;
		IO output;

		uint limit;
		uint count;

		IO fee;
	}

	/// @notice mapping of recipe id to recipe
	mapping (uint => Recipe) private _recipes;
	Counters.Counter private _recipesCounter;

	event Crafted (uint indexed id, address indexed sender);

	/**
	 * @notice Modifier to check if the recipe exists and limit has not been reached
	 */

	modifier onlyActive (uint id) {
		require(_recipes[id].input.token != address(0), 'BaliTwinForge: recipe does not exist');
		require(_recipes[id].count < _recipes[id].limit, 'BaliTwinForge: recipe limit reached');
		_;
	}

	// Public functions

	/**
	 * @notice Craft an item using a recipe
	 * 
	 * @param id Recipe id
	 * 
	 * @dev Input and fee token must be approved for transfer
	 * @dev Output token must be approved for minting
	 */

	function craft (uint id) payable public onlyActive(id) {
		Recipe memory recipe = _recipes[id];

		// Payment

		if (recipe.fee.token == address(0))
			require(msg.value == recipe.fee.amounts[0], 'BaliTwinForge: invalid fee amount');
		
		else if (ERC721(recipe.fee.token).supportsInterface(type(IERC721).interfaceId))
			ERC721(recipe.fee.token).transferFrom(msg.sender, address(this), recipe.fee.ids[0]);

		else if (ERC1155(recipe.fee.token).supportsInterface(type(IERC1155).interfaceId))
			ERC1155(recipe.fee.token).safeTransferFrom(msg.sender, address(this), recipe.fee.ids[0], recipe.fee.amounts[0], '');

		else require(
			ERC20(recipe.fee.token).transferFrom(msg.sender, address(this), recipe.fee.amounts[0]),
			'BaliTwinForge: transfer failed'
		);

		// Burn input
			
		if (ERC721(recipe.input.token).supportsInterface(type(IERC721).interfaceId))
			ERC721(recipe.input.token).burn(recipe.input.ids[0]);
		
		else if (ERC1155(recipe.input.token).supportsInterface(type(IERC1155).interfaceId))
				ERC1155(recipe.input.token).burnBatch(msg.sender, recipe.input.ids, recipe.input.amounts);
	
		else ERC20(recipe.input.token).burnFrom(msg.sender, recipe.input.amounts[0]);

		// Mint output

		if (ERC721(recipe.output.token).supportsInterface(type(IERC721).interfaceId))
			ERC721(recipe.output.token).mint(msg.sender, recipe.output.ids[0], '');

		else if (ERC1155(recipe.output.token).supportsInterface(type(IERC1155).interfaceId))
			ERC1155(recipe.output.token).mintBatch(msg.sender, recipe.output.ids, recipe.output.amounts, '');
		
		else ERC20(recipe.output.token).mint(msg.sender, recipe.output.amounts[0]);

		_recipes[id].count++;
		emit Crafted(id, msg.sender);
	}

	/**
	 * @notice Get recipe details
	 * 
	 * @param id Recipe id
	 */

	function getRecipe (uint id) public view returns (Recipe memory) {
		return _recipes[id];
	}

	/**
	 * @notice Get all active recipes ids
	 */

	function getActiveRecipes () public view returns (uint[] memory) {
		uint[] memory active = new uint[](_recipesCounter.current());
		uint counter = 0;

		for (uint i = 0; i < _recipesCounter.current(); i++) {
			if (_recipes[i].count < _recipes[i].limit) {
				active[counter] = i;
				counter++;
			}
		}

		return active;
	}

	// Owner functions	

	/**
	 * @notice Add a new recipe
	 * 
	 * @return id Recipe id
	 */

	function addRecipe (IO calldata input, IO calldata output, IO calldata fee, uint limit) public onlyOwner returns (uint) {
		require(limit > 0, 'BaliTwinForge: limit must be greater than 0');
		
		require(input.token != address(0), 'BaliTwinForge: input token cannot be zero address');
		require(output.token != address(0), 'BaliTwinForge: output token cannot be zero address');

		require(fee.ids.length == fee.amounts.length, 'BaliTwinForge: fee ids and amounts length mismatch');
		require(input.ids.length == input.amounts.length, 'BaliTwinForge: input ids and amounts length mismatch');
		require(output.ids.length == output.amounts.length, 'BaliTwinForge: output ids and amounts length mismatch');
		
		uint id = _recipesCounter.current();

		_recipes[id] = Recipe(input, output, limit, 0, fee);
		_recipesCounter.increment();

		return id;
	}
	
	/**
	 * @notice Update a recipe fee
	 * 
	 * @param id Recipe id
	 * @param fee New fee
	 */

	function setRecipeFee (uint id, IO calldata fee) public onlyOwner {
		_recipes[id].fee = fee;
	}

	/**
	 * @notice Update a recipe limit
	 * 
	 * @param id Recipe id
	 * @param limit New limit
	 */

	function setRecipeLimit (uint id, uint limit) public onlyOwner {
		require(_recipes[id].count < limit, 'BaliTwinForge: recipe count is higher than limit');
		_recipes[id].limit = limit;
	}

	/**
	 * @notice Withdraw tokens from the contract
	 * 
	 * @param token Token address
	 * @param amount Amount to withdraw
	 * @param to Recipient address
	 */
	
	function withdraw (address token, uint amount, address to) public onlyOwner {
		if (token == address(0))
			payable(to).transfer(amount);

		else ERC20(token).transfer(to, amount);
	}

	receive () external payable {}

	fallback () external payable {}

}