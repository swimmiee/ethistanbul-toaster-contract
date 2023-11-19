// valures provided in args array

console.log(`get new range of ${args}`);


if (!secrets.apiKey) {
    throw Error(
        "COINMARKETCAP_API_KEY environment variable not set for CoinMarketCap API"
    )
}
// build HTTP request object
const token0Id = args[0];
const token1Id = args[1];
const tickSpacing = args[2];
const tokenRequest = Promise.all([Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`,
    headers: {
        "Content-Type": "application/json",
        "X-CMC_PRO_API_KEY": secrets.apiKey,
    },
    params: {
        convert: currencyCode,
        id: token0Id,
    },
}), Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`,
    headers: {
        "Content-Type": "application/json",
        "X-CMC_PRO_API_KEY": secrets.apiKey,
    },
    params: {
        convert: currencyCode,
        id: token1Id,
    }
})]).catch((error) => {
    throw Error(`Error fetching token data from CoinMarketCap: ${error}`)
});

// fetch the price
const price0 =
  coinMarketCapResponse.data.data[token0Id]["quote"][currencyCode][
    "price"
    ];
const price1 =
  coinMarketCapResponse.data.data[token0Id]["quote"][currencyCode][
    "price"
    ];
const currentRatio = (price0 / price1);
const sqrtPrice  = Math.sqrt(currentRatio) * 2 ** 96;
const currentTick= Math.log(sqrtPrice.toNumber()) / Math.log(Math.sqrt(1.0001))
//various strategies for getting the data
const newTickLower = Math.floor(currentTick / tickSpacing) * tickSpacing - tickSpacing*3;
const newTickUpper = Math.floor(currentTick / tickSpacing) * tickSpacing + tickSpacing * 3


return Functions.encodeUint256(newTickLower, newTickUpper)
