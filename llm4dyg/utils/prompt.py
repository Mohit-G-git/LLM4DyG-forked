
def get_imp(imp):
    if imp == 0:
        return f""
    elif imp == 24:
        return f'Pick time and then nodes. \n'
    elif imp == 25:
        return f'Pick nodes and then time. \n'
    elif imp == 26:
        return f"Take a deep breath and work on this problem step-by-step. \n"
    elif imp == 27:
        return f'Think nodes and then time. \n'
    elif imp == 28:
        return f'Think time and then nodes. \n'
    else:
        raise NotImplementedError()
    
import types

class DyGraphPrompt:
    def __init__(self, obj_task, args) -> None:
        add_cot = args.add_cot
        add_role = args.add_role
        num_examplars = args.num_examplars
        dyg_type = args.dyg_type
        
        self.instructor_role = "You are an excellent dynamic network analyzer, with a good understanding of the structure of the graph and its evolution through time. \n"
        if dyg_type == 0:
            self.instructor_dyg = f"A dynamic graph is represented as a list of tuples, where each tuple (u, v, t) denotes that there is an edge at time t between node u and node v. For example, (6, 5, 2) denotes that node 6 is linked with node 5 at time 2. \n"
        elif dyg_type == 1:
            self.instructor_dyg = f"In an undirected dynamic graph, (u, v, t) means that node u and node v are linked with an undirected edge at time t.\n"
        else:
            raise NotImplementedError(f"dyg_type {dyg_type} not implemented")
        
        self.args = args
        if args:
            imp = self.args.__dict__.get("imp", 0)
        else:
            imp = 0
            
        self.prompt_imp = get_imp(imp)
        
        # Make CoT prompt dynamic based on task
        if args and args.task == 'when_link':
            self.prompt_cot = (
                "Let's solve this step-by-step.\n"
                "Go through EACH edge one at a time:\n"
                "- For each edge (u, v, t), check: does {u, v} equal the set of queried nodes?\n"
                "- If YES, add t to your result list.\n"
                "- If NO, skip it.\n"
                "After checking ALL edges, output your collected list.\n"
            )
        elif args and args.task == 'what_node':
            self.prompt_cot = (
                "Let's solve this step-by-step.\n"
                "Go through EACH edge one at a time:\n"
                "- For each edge (u, v, t), check: does t equal the queried time AND does {u, v} contain the queried node?\n"
                "- If YES, add the OTHER node to your result list.\n"
                "- If NO, skip it.\n"
                "After checking ALL edges, output your collected list of nodes.\n"
            )
        elif args and args.task == 'which_neighbor':
            self.prompt_cot = (
                "Let's solve this step-by-step.\n"
                "Go through EACH edge one at a time:\n"
                "- First, check if the edge contains the queried node. If it doesn't, skip it entirely.\n"
                "- If it does contain the queried node, check the time t.\n"
                "- If t <= the queried time, the other node is EXCLUDED.\n"
                "- If t > the queried time, the other node is a CANDIDATE.\n"
                "Finally, return the CANDIDATES that were NEVER EXCLUDED.\n"
            )
        elif args and args.task == 'check_tclosure':
            self.prompt_cot = "Let's solve this step-by-step.\nCheck if all three pairs formed by the three nodes have an edge between them at any time in the graph. If yes, return 'yes', else return 'no'.\n"
        elif args and args.task == 'check_tpath':
            self.prompt_cot = "Let's solve this step-by-step.\nTraverse the given path node by node, finding the earliest valid edge at each step that connects the current node to the next node without decreasing the time. If you can reach the end, return 'yes', else return 'no'.\n"
        elif args and args.task == 'find_tpath':
            self.prompt_cot = "Let's solve this step-by-step.\nStart at the given node and find a sequence of at least 3 nodes connected by edges whose times do not decrease.\n"
        elif args and args.task == 'sort_edge':
            self.prompt_cot = "Let's solve this step-by-step.\nList the time for each edge, then sort the edges from the earliest time to the latest time.\n"
        else:
            self.prompt_cot = "Let's work exactly step-by-step to avoid errors.\n"
            
        self.add_cot = add_cot
        self.add_role = add_role
        self.num_examplars = num_examplars
        self.obj_task = obj_task
        
    def generate_prompt_qa(self, context, query = None, answer = None, *args, **kwargs):
        # generate prompt components
        instructor_role, instructor_dyg = self.instructor_role if self.add_role else "", self.instructor_dyg
        prompt_cot = self.prompt_cot if self.add_cot else ""
        
        prompt_context = self.obj_task.generate_context_prompt(context)
        instructor_task = self.obj_task.generate_instructor_task()
        instructor_answer = self.obj_task.generate_instructor_answer()
        prompt_examplars = self.obj_task.generate_prompt_examplars(self.num_examplars) if self.num_examplars else ""
        prompt_question = self.obj_task.generate_prompt_question(query)

        # prompt_seq = [
        #     instructor_role,
        #     instructor_dyg,
        #     instructor_task,
        #     self.prompt_imp,
        #     instructor_answer,
        #     prompt_examplars,
        #     prompt_context,
        #     prompt_question,
        #     prompt_cot
        # ]
        prompt_seq = [
            instructor_role,         # role context (if enabled)
            instructor_dyg,          # explain what (u, v, t) means
            instructor_task,         # what the task is
            self.prompt_imp,         # improvement prompt (if any)
            prompt_examplars,        # few-shot examples
            instructor_answer,       # answer format instruction
            prompt_context,          # the actual graph data
            prompt_question,         # the concrete question
            prompt_cot,              # chain-of-thought (if enabled)
        ]


        final_constraint = (
            "\nIMPORTANT:\n"
            "The dynamic graph and all required information are already fully provided above.\n"
            "Do NOT ask for more information.\n"
        )
        if self.args and self.args.task == 'when_link':
            final_constraint += "Scan each edge (u, v, t) and collect time t whenever u and v match the two queried nodes (in either order).\n"
        elif self.args and self.args.task == 'what_node':
            final_constraint += "Scan each edge (u, v, t) and collect the other node whenever the time t matches the queried time AND one of the nodes matches the queried node.\n"
        elif self.args and self.args.task == 'which_neighbor':
            final_constraint += "Follow the step-by-step reasoning to strictly exclude nodes linked before the given time.\n"
        elif self.args and self.args.task == 'check_tclosure':
            final_constraint += "Ensure all three required edges exist in the graph before answering 'yes'.\n"
        elif self.args and self.args.task == 'check_tpath':
            final_constraint += "Ensure the edge times never decrease along the path before answering 'yes'.\n"
        elif self.args and self.args.task == 'find_tpath':
            final_constraint += "Ensure the path length is at least 3 (i.e., at least 3 nodes, 2 edges).\n"
        if self.add_cot:
            final_constraint += "Output your step-by-step reasoning first, and place strictly your final result on the last line prefixed with 'Answer: '.\n"
        else:
            final_constraint += "Output ONLY the final answer strictly in the required format.\n"
            
        # prompt_seq = [
        #     instructor_dyg,
        #     instructor_task,
        #     prompt_examplars,
        #     final_constraint,
        #     prompt_context,
        #     prompt_question
        # ]

        prompt_seq.append(final_constraint)
        
        if self.args:
            short = self.args.__dict__.get("short", 0)
            if short==1:
                prompt_seq.append('Give a short answer.')
            elif short==2:
                prompt_seq.append('Note that the time represents year, month, day, for example, 20200925 means 25th day in September in 2020, and 19990102 < 20200925 < 20231207')
            elif short==3:
                prompt_seq.append('Note that the time represents unix timestamp, for example, 1348839350 < 1476979078 < 1547036558')
        
        prompt = "".join(prompt_seq)
        
        prompt_qa = {
            "prompt": prompt,
            "answer": answer,
        }
        return prompt_qa