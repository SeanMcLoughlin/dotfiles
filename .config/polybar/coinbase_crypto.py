from coinbase.wallet.client import Client
from coinbase.wallet.model import APIObject

api_key = "Q5UAmU7czpHldqJg"
api_secret = "xwxe0nTgTRiQSQHsbXahTkcGrFlF26KW"
client = Client(api_key, api_secret)
# client._make_api_object(client._get('v2', 'prices', 'ETH-USD', 'historic'), APIObject)

price = client.get_spot_price(currency_pair='ETH-USD')

print(price)
