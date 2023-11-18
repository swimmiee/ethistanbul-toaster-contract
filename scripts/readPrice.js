import { ethers } from "hardhat"

async function readPrice() {
    const priceConsumerV3 = await ethers.getContract("PriceConsumerV3")
    const price = await priceConsumerV3.getLatestPrice()
    console.log(price.toString())
}

readPrice()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
