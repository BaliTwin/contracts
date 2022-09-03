import { ethers } from 'hardhat'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

const { defaultAbiCoder : AbiCoder, keccak256, toUtf8Bytes, hexlify } = ethers.utils

export const NAME_MARKET = 'BaliTwinMarket'
export const NAME_721 = 'Collection721'
export const SYMBOL_721 = 'ITEM721'
export const NAME_1155 = 'Collection1155'
export const SYMBOL_1155 = 'ITEM1155'
export const META_URI = 'ipfs://QmfPEreRexqckoExqHv1hGU5xirKjqAKW3cpmFpy1AgjBe'

export const nullData = AbiCoder.encode(['uint'], [0])
export const randomPrice = () => (Math.random() * 100 >> 0 || 1) * 10 ** 6
export const randomInt = () => Math.random() * 10 >> 0
export const ipfsCID = () => 
	hexlify(keccak256(toUtf8Bytes(String(Math.random()))))

export const accessError = (role, caller) => `AccessControl: account ${caller.toLowerCase()} is missing role ${role}`

console.log(invoice(0))

export function invoice (price = randomPrice()) {
	return AbiCoder.encode(
		['uint'], [BigInt(price)]
	)
}

export async function deploy (name : string, ...args) {
	const contract = await ethers
		.getContractFactory(name)
		.then(f => f.deploy(...args))

	await contract.deployed()
	return contract
}

export async function usdt () {
	const USDT = await deploy('USDT')
	const decimals = await USDT.decimals()
	const wallets = await ethers.getSigners()

	for (const wallet of wallets) {
		await USDT.connect(wallet).mint(100_000_000 * 10 ** decimals)
	}

	return { USDT, wallets }
}

export async function contracts () {
	const { USDT } = await usdt()

	const [Market, Collection721, Collection1155] = await Promise.all(
		[
			[NAME_MARKET, USDT.address],
			[NAME_721, NAME_721, SYMBOL_721, META_URI],
			[NAME_1155, NAME_1155, SYMBOL_1155, META_URI]
		].map(
			([name, ...args]) => loadFixture(() => deploy(name, ...args))
		)
	)

	return { Market, Collection721, Collection1155, USDT }
}

export async function list721 ({ author, seller, Market } : any) {
	author ??= (await ethers.getSigners())[0]
	seller ??= author

	const { Collection721, Market: _market } = await contracts()
	Market ??= _market
				
	await Collection721.grantRole(await Collection721.AUTHOR_ROLE(), author.address)
	await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection721.address)

	const uri = ipfsCID()
	const price = randomPrice()
	const id = await Collection721
		.connect(seller)
		.mint(Market.address, ipfsCID(), invoice(price))
		.then(tx => tx.wait())
		.then(tx => tx.events[0].args.tokenId)

	return { id, uri, price, author, seller, Collection721, Market }
}

export async function list1155 ({ author, seller, Market } : any) {
	author ??= (await ethers.getSigners())[0]
	seller ??= author

	const { Collection1155, Market: _market } = await contracts()
	Market ??= _market
				
	await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
	await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

	const price = randomPrice()
	const id = await Collection1155
		.connect(seller)
		.mint(Market.address, ipfsCID(), 1, invoice(price))
		.then(tx => tx.wait())
		.then(tx => tx.events[0].args.id)

	return { id, price, author, seller, Market, Collection1155 }
}

export async function listBatch1155 ({ author, seller, Market } : any) {
	author ??= (await ethers.getSigners())[0]
	seller ??= author
	
	const { Collection1155, Market: _market, USDT } = await contracts()
	Market ??= _market
				
	await Collection1155.grantRole(await Collection1155.AUTHOR_ROLE(), author.address)
	await Market.grantRole(await Market.VERIFIED_COLLECTION(), Collection1155.address)

	const cids = await Promise.all(Array(5).fill(0).map(ipfsCID))
	const amounts = cids.map(() => (Math.random() * 10 >> 0) || 1)
	const prices = cids.map(randomPrice)
	const invoices = AbiCoder.encode(
		['bytes[]'], [prices.map(price => invoice(price))]
	)

	const ids = await Collection1155
		.connect(seller)
		.mintBatch(Market.address, cids, amounts, invoices)
		.then(tx => tx.wait())
		.then(tx => tx.events[0].args.ids)

	const items = ids.map((id, i) => ({
		id,
		price: prices[i],
		author,
		seller
	}))

	return { items, author, seller, Market, Collection1155, USDT }
}

export async function listAndBuyBatch1155 () {
	const { USDT, Market } = await contracts()
			
	const { Collection1155 } = await listBatch1155({ Market })
	const [id] = await Market.items()
	const item = await Market.item(id)
	const amount = await Collection1155.balanceOf(Market.address, item.id)

	const [buyer] = await ethers.getSigners()

	await USDT.connect(buyer).approve(Market.address, item.price * amount)
	await Market.connect(buyer).buy(id, amount)

	return {
		Collection1155, USDT, Market, item, buyer
	}
}