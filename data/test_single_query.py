#!/usr/bin/env python3
"""Test a single problematic query to debug"""

import sys
sys.path.insert(0, 'scripts')
from run_query import query_rag

print('Testing: what is tax on sale of property?')
print('='*80)
answer = query_rag('what is tax on sale of property?', top_k=6)
print('\n' + '='*80)
print(f'Answer length: {len(answer)} chars')
print(f'Words: {len(answer.split())} words')
print(f'Complete: {answer[-1] in ".!?" if answer else False}')
print('='*80)
print('FULL ANSWER:')
print(answer)
