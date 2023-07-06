from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import openai
import requests
from bs4 import BeautifulSoup

API_KEY = ""
openai.api_key = API_KEY


def get_embedding(text, model="text-embedding-ada-002"):
    text = text.replace("\n", " ")
    text = text.replace("\r", " ")
    return openai.Embedding.create(input=[text], model=model)["data"][0]["embedding"]


# Parse the novel

response = requests.get("https://www.gutenberg.org/files/1184/1184-h/1184-h.htm")
soup = BeautifulSoup(response.text, "html.parser")
h3_tags = soup.find_all("h3")[1:]
chapters_to_text = {tag.get_text(): [] for tag in h3_tags}

idx = 0

next_element = h3_tags[idx]

while next_element.name != "hr":

    next_element = next_element.find_next()

    if next_element.name == "h3":
        idx += 1

    if next_element.name == "p":
        text = next_element.get_text()
        chapters_to_text[h3_tags[idx].get_text()].append(text)


# create embeddings keeping in mind token limit

MAX_PARAGRAPHS = 20

embeddings = []

for chapter, paragraphs in chapters_to_text.items():

    for i in range(len(paragraphs) // MAX_PARAGRAPHS):
        text = "/n".join(paragraphs[i * MAX_PARAGRAPHS : (i + 1) * MAX_PARAGRAPHS])
        embedding = get_embedding(text, model="text-embedding-ada-002")
        embeddings.append((chapter, text, embedding))

# create qdrant collection

qdrant = QdrantClient(":memory:")  # change to IP for remote server

qdrant.recreate_collection(
    collection_name="dumas",
    vectors_config=VectorParams(size=1536, distance=Distance.COSINE),
    shard_number=6, # number of shards
    replication_factor=2, # number of shard replicas    
)

qdrant.upsert(
    collection_name="dumas",
    points=[
        PointStruct(id=idx, vector=vector, payload={"chapter": chapter, "text": text})
        for idx, (chapter, text, vector) in enumerate(embeddings)
    ],
)

# query the database

query_vector = get_embedding(
    "Let it be, then, as you wish, sweet angel; God has sustained me in my struggle with my enemies, and has given me this reward; he will not let me end my triumph in suffering; I wished to punish myself, but he has pardoned me."
)

hits = qdrant.search(
    collection_name="dumas",
    query_vector=query_vector,
    limit=5,  # Return 5 closest points
)
