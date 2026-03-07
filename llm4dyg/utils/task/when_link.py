from .base import DyGraphTask
import numpy as np
import re

def find_neighbors(x, con):
    res = set()
    for e1,e2,t in con:
        if e1 == x:
            res.add(e2)
        if e2 == x:
            res.add(e1)
    return list(res)
    
    
class DyGraphTaskWhenLink(DyGraphTask):
    def generate_qa(self, info, *args, **kwargs):
        context = info['edge_index']
        context = np.array(context)

        answer = set()
        
        # select n1
        nodes = list(set(list(context[:, :2].flatten())))
        n1 = int(np.random.choice(nodes))
        
        # select n2
        n1nodes = find_neighbors(n1, context)
        n2 = int(np.random.choice(n1nodes))

        # give answer
        for e1,e2,t in context:
            if (e1 == n1 and e2 == n2) or (e1 == n2 and e2 == n1):
                answer.add(int(t))
        answer = list(answer)
        context = context.tolist()
        qa = {
            "context": context,
            "query": [n1, n2],
            "answer": answer,
            "task": self.task
        }
        try:
            assert len(answer) > 0
        except Exception as e:
            import pdb; pdb.set_trace()
        return qa
    
    def generate_instructor_task(self, *args, **kwargs):
        return f"Your task is to find ALL time steps at which two specified nodes share a direct edge in the dynamic graph.\nFor each edge (u, v, t), check if u and v match the two queried nodes (in either order). If they match, include t in your answer.\n"
    
    def generate_instructor_answer(self, *args, **kwargs):
        return "Give the answer as a python list at the last of your response after 'Answer:'.\n"

    def generate_prompt_examplars(self, num, *args, **kwargs):
        qa = [
            [
                [(0, 2, 0), (0, 3, 1), (1, 2, 5), (3, 1, 6)],
                [0, 3], 
                [1]
            ],
            [
                [(1, 3, 1), (0, 3, 2), (3, 5, 5)],
                [3, 5], 
                [5]
            ]
        ]
        return self.make_qa_example(num, qa)
    
    def generate_prompt_question(self, query = None, *args, **kwargs):
        return f"When are node {query[0]} and node {query[1]} linked? Look through each edge and find all times t where the edge connects node {query[0]} and node {query[1]}.\n"
    
    def evaluate(self, qa, response):
        ans = qa['answer']
        # Try: Answer: [1, 2, 3]
        match = re.search(r"Answer:\s*\[([\d,\s]+)\]", response)
        if match:
            numbers_str = match.group(1)
            numbers = [int(num) for num in numbers_str.split(',')]
            metric = (set(numbers) == set(ans))
            return metric
        # Try: Answer: [] (empty list)
        match = re.search(r"Answer:\s*\[\s*\]", response)
        if match:
            return len(ans) == 0
        # Try: Answer: 5 (single number, no brackets)
        match = re.search(r"Answer:\s*(\d+)\s*", response)
        if match:
            answer = int(match.group(1))
            return set([answer]) == set(ans)
        # Try: "answer is [1, 2, 3]"
        match = re.search(r"""answer is\s*[:`'"]?\s*\[([\d,\s]+)\]""", response)
        if match:
            numbers_str = match.group(1)
            numbers = [int(num) for num in numbers_str.split(',')]
            metric = (set(numbers) == set(ans))
            return metric
        # Try: "answer is 5"
        match = re.search(r"""answer is\s*[:`'"]?\s*(\d+)\s*""", response)
        if match:
            answer = int(match.group(1))
            return set([answer]) == set(ans)
        # Try: "at time [1, 2]"
        match = re.search(r"""at time\s*[:`'"]?\s*\[([\d,\s]+)\]""", response)
        if match:
            numbers_str = match.group(1)
            numbers = [int(num) for num in numbers_str.split(',')]
            metric = (set(numbers) == set(ans))
            return metric
        # Try: "at time 5"
        match = re.search(r"at time\s*(\d+)\s*", response)
        if match:
            answer = int(match.group(1))
            return set([answer]) == set(ans)
        # Last resort: find any bracketed list of numbers in the response
        match = re.search(r"\[([\d,\s]+)\]", response)
        if match:
            numbers_str = match.group(1)
            numbers = [int(num) for num in numbers_str.split(',')]
            metric = (set(numbers) == set(ans))
            return metric
        return -1
                                