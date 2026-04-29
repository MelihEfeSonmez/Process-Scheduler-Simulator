EXEC=schedsim
TEST_DIR=test-cases
OUTPUT_DIR=my-outputs

OBJS = src/fcfs.o src/parser.o src/pf.o src/rr.o src/schedsim.o src/sjf.o src/srtf.o

.PHONY: all testcases grade clean

all: $(EXEC)

$(EXEC): $(OBJS)
	ld -o $(EXEC) $(OBJS)

src/fcfs.o: src/fcfs.s
	as -o src/fcfs.o src/fcfs.s

src/parser.o: src/parser.s
	as -o src/parser.o src/parser.s

src/pf.o: src/pf.s
	as -o src/pf.o src/pf.s

src/rr.o: src/rr.s
	as -o src/rr.o src/rr.s

src/schedsim.o: src/schedsim.s
	as -o src/schedsim.o src/schedsim.s

src/sjf.o: src/sjf.s
	as -o src/sjf.o src/sjf.s

src/srtf.o: src/srtf.s
	as -o src/srtf.o src/srtf.s

testcases: $(EXEC)
	@echo "Running test cases..."
	@mkdir -p $(OUTPUT_DIR)
	@for infile in $(TEST_DIR)/input_*.txt; do \
		base=$$(basename $$infile); \
		outfile=$$(echo $$base | sed 's/input_/output_/'); \
		echo "  > $$infile -> $(OUTPUT_DIR)/$$outfile"; \
		./$(EXEC) < $$infile > $(OUTPUT_DIR)/$$outfile; \
	done

grade: $(EXEC)
	python3 test/grader.py ./$(EXEC) $(TEST_DIR)

clean:
	rm -f $(EXEC) $(OBJS)
	rm -rf $(OUTPUT_DIR)
