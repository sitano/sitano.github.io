---
layout: post
title: System design problem - w-shingles search engine
categories: [distsys, problems]
tags: [distsys, problems, task, interview, test]
mathjax: true
source: "antiplagiat, https://habr.com/ru/company/antiplagiat/blog/445952/"
---

You are asked to develop a system that helps scientists to answer
a question whether their papers contain non-unique content (are plagiarism).
The system will index millions of documents and check whether a document
from the input contains pieces from other (indexed) documents.

## Task

Develop a w-shingles search engine that exposes following API:

* POST /index/add {doc\_id: uint64, shingles: []uint64} - index a document
* POST /index/search {shingles: []uint64} - search index for a ranked document ids

Where a document is a text that is translated into a sequence of shingles:

    text:string → shingles:uint64[]

A search query returns a list of ranked documents ordered by the size of
intersection of their its and the ones from the request set.

## Constaints

- Search _shingles_ set is up to _10^6_ per query.
- Index size: index contain about 10^9 documents (~10^12 shingles).
- Search must handle at least 300\*10^3 request per day.
- Index filling must handle 4000 RPS.
- All these constraints must be met with a single machine.
- The system must be able to scale beyond the single machine.

[1]: https://en.wikipedia.org/wiki/W-shingling "w-shingles"
