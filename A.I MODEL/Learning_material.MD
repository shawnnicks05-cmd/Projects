# AI Engineering & Large Language Models (LLMs) Learning Roadmap

This comprehensive roadmap is designed to take you from a complete beginner to deeply understanding how AI works, how to manage AI databases, and how to create your own production-ready applications.

---

## 🗺️ Phase 1: The Fundamentals (How AI "Thinks")
**Goal:** Understand the core mechanics of Large Language Models (LLMs) without getting bogged down in heavy math.

### 🧠 Concepts to Learn
* **Tokens & Tokenization:** How raw text is broken down into manageable chunks (sub-words, characters, or full words) for the model to process.
* **Embeddings & Vector Space:** The mechanism by which words are transformed into multi-dimensional numerical coordinates, allowing the AI to understand semantic relationships and meaning.
* **The Transformer Architecture:** Deep dive into **Self-Attention** mechanics—how an AI evaluates the contextual relationships between all words in a sentence simultaneously.

### 🛠️ Action Items & Practices
- [ ] Experiment with the online [OpenAI Tokenizer Tool](https://platform.openai.com/tokenizer) to visualize how different sentences are parsed into token groups.
- [ ] Watch or read introductory conceptual explanations of the *Transformer architecture* focusing specifically on visual animations of attention weights.

---

## 🗄️ Phase 2: Data for AI (Vector Databases & RAG)
**Goal:** Learn how to supply an AI with long-term memory and customized knowledge using external data systems.

### 🧠 Concepts to Learn
* **What is a Vector Database?** Understand how multi-dimensional spatial databases differ fundamentally from traditional relational databases (SQL) or document stores (NoSQL).
* **Distance Metrics:** Learn how systems mathematically calculate semantic similarity using algorithms like **Cosine Similarity**, **Euclidean Distance**, and **Dot Product**.
* **Retrieval-Augmented Generation (RAG):** Master the 3-step paradigm:
  $$\text{User Prompt} \longrightarrow \text{Vector Database Context Retrieval} \longrightarrow \text{LLM Context-Aware Generation}$$

### 🛠️ Action Items & Practices
- [ ] Register for a free tier account on a managed vector database platform (e.g., **Pinecone**, **Qdrant**) or spin up an instance of **Supabase** with the `pgvector` extension enabled.
- [ ] Review the official "Quickstart Guide" for your chosen database and practice manually inserting dummy vector coordinates.

---

## 💻 Phase 3: Putting it Together (Coding & Frameworks)
**Goal:** Learn the software engineering toolkits and orchestrators that connect foundational models to your custom databases.

### 🧠 Concepts to Learn
* **AI Orchestration Frameworks:** Study industry-standard abstraction layers that simplify AI application code. Focus on **LangChain** and **LlamaIndex**.
* **API Interfacing:** Understand how to properly authenticate, structure payloads, and handle asynchronous streaming responses from major API providers (OpenAI, Anthropic, Google Gemini).

### 🛠️ Action Items & Practices
- [ ] Establish a strong grasp of foundational Python (variables, loops, dicts, async operations) since the AI ecosystem is overwhelmingly Python-dominant.
- [ ] Complete a code tutorial to construct a minimal RAG script (often under 20 lines of code) utilizing LangChain components.

---

## 🚀 Phase 4: Practical Application (Build Your Own)
**Goal:** Synthesize your learning by engineering a functional, production-inspired AI tool.

### 💡 Project Idea: "Chat with My Document Collection"
Build a script or web service that allows a user to upload files and ask natural language questions about them.

1. **Extraction:** Write a routine to pull clean text strings out of local PDF or markdown documents.
2. **Embedding generation:** Pipe the text chunks into an embedding model API to receive text vectors.
3. **Storage:** Upsert the resulting vectors alongside their text metadata into your free-tier vector database.
4. **Execution:** Build a terminal loop or basic interface that queries the vector database for matching blocks, appends them to the user's prompt as context, and streams the answer back from an LLM.

---

## 📚 Recommended Free Resources to Start

### 📺 YouTube Channels
* **3Blue1Brown:** Exceptional visual mathematical animations explaining neural networks, calculus, and linear algebra basics.
* **Andrej Karpathy:** The former Director of AI at Tesla and OpenAI co-founder. His lecture *"Intro to Large Language Models"* is essential viewing for anyone entering the space.

### 🎓 Structured Courses
* **DeepLearning.AI:** Offers highly-regarded, free short courses addressing prompt engineering, framework utilization (LangChain/LlamaIndex), and vector indexing optimization.