import chromadb

client = chromadb.PersistentClient(path="chroma_data")

source = client.get_collection("documents")
target = client.create_collection(
    name="documents_cosine_v1",
    configuration={"hnsw": {"space": "cosine"}},
)

total = source.count()

for offset in range(0, total, 100):
    batch = source.get(
        limit=100,
        offset=offset,
        include=["documents", "metadatas", "embeddings"],
    )

    target.add(
        ids=batch["ids"],
        documents=batch["documents"],
        metadatas=batch["metadatas"],
        embeddings=batch["embeddings"],
    )

assert target.count() == total, "Document count mismatch."
assert target.configuration["hnsw"]["space"] == "cosine"

print(f"Copied {total} chunks into documents_cosine_v1.")
print("Original documents collection preserved.")