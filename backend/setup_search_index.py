import os
from pathlib import Path

from dotenv import load_dotenv
from azure.core.credentials import AzureKeyCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    HnswParameters,
    VectorSearchProfile,
)

load_dotenv(Path(__file__).resolve().parent / ".env")

index = SearchIndex(
    name=os.environ["AZURE_SEARCH_INDEX"],
    fields=[
        SimpleField(
            name="id",
            type=SearchFieldDataType.String,
            key=True,
        ),
        SimpleField(
            name="document_id",
            type=SearchFieldDataType.String,
            filterable=True,
        ),
        SimpleField(name="filename", type=SearchFieldDataType.String),
        SimpleField(
            name="upload_date",
            type=SearchFieldDataType.String,
            sortable=True,
        ),
        SimpleField(name="chunk_index", type=SearchFieldDataType.Int32),
        SearchableField(name="text", type=SearchFieldDataType.String),
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=384,
            vector_search_profile_name="cosine-profile",
        ),
    ],
    vector_search=VectorSearch(
        algorithms=[
            HnswAlgorithmConfiguration(
                name="cosine-hnsw",
                parameters=HnswParameters(metric="cosine"),
            )
        ],
        profiles=[
            VectorSearchProfile(
                name="cosine-profile",
                algorithm_configuration_name="cosine-hnsw",
            )
        ],
    ),
)

if __name__ == "__main__":
    with SearchIndexClient(
        endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
        credential=AzureKeyCredential(
            os.environ["AZURE_SEARCH_ADMIN_KEY"]
        ),
    ) as client:
        client.create_index(index)
        print(f"Created index: {index.name}")