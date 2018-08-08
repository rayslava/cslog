BINARY=cslog
JOBS=$(shell grep -c '^processor' /proc/cpuinfo)
VERBOSE=1
MAKE=cmake --build . -- -j $(JOBS)
all: stylecheck doxygen asan-release tsan-release clang release clang-release analyzed

doxygen:
	doxygen Doxyfile

build-dir = \
	rm -rf $1-build && mkdir $1-build && cd $1-build

debug:
	$(call build-dir, $@) && cmake .. -DCMAKE_EXPORT_COMPILE_COMMANDS=True -DCMAKE_BUILD_TYPE=Debug && $(MAKE) -j $(JOBS) && ctest -j 1

release: debug
	$(call build-dir, $@) && cmake .. -DCMAKE_BUILD_TYPE=Release && $(MAKE) && ctest -j 1

static:
	$(call build-dir, $@) && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DSTATIC=True && $(MAKE) $(BINARY) -j $(JOBS)

static-release:
	$(call build-dir, $@) && cmake .. -DCMAKE_BUILD_TYPE=Release -DSTATIC=True && $(MAKE) $(BINARY) -j $(JOBS)

asan:
	$(call build-dir, $@) && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address" -DCMAKE_BUILD_TYPE=Debug && $(MAKE) && ctest -j 1 -R unit

asan-release:
	$(call build-dir, $@) && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address" -DCMAKE_BUILD_TYPE=RelWithDebInfo && $(MAKE) && ctest -j 1 -R unit

tsan:
	$(call build-dir, $@) && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=thread"  -DCMAKE_BUILD_TYPE=Debug && $(MAKE) && ctest -j 1 -R unit

tsan-release:
	$(call build-dir, $@) && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=thread"  -DCMAKE_BUILD_TYPE=RelWithDebInfo && $(MAKE) && ctest -j 1 -R unit

lsan:
	$(call build-dir, $@) && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=leak"  -DCMAKE_BUILD_TYPE=RelWithDebInfo && $(MAKE) && ctest -j 1 -R unit

clang:
	$(call build-dir, $@) && CXX=clang++ CC=clang  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=True .. && $(MAKE) $(BINARY)

clang-release:
	$(call build-dir, $@) && CXX=clang++ CC=clang cmake .. -DCMAKE_BUILD_TYPE=Release && $(MAKE) $(BINARY) -j $(JOBS)

analyzed:
	$(call build-dir, $@) && scan-build cmake ..  && scan-build $(MAKE) $(BINARY)

tidy:
	$(call build-dir, $@) && cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=True ..  && clang-tidy -p debug-build ../src/*.cpp

clean:
	rm -rf *-build doc/html; find -name '*~' -delete; rm -f dockerbuild/$(BINARY).tar.gz; rm -f dockerbuild/$(BINARY)

memcheck-binary = \
	(valgrind --tool=memcheck --track-origins=yes --leak-check=full --trace-children=yes --show-reachable=yes ./$1 2>/tmp/unit-test-valg-$1.log)</dev/null && sed '/in use/!d;s/.*exit:.*\s\([[:digit:]]\+\)\sblocks.*/\1/' /tmp/unit-test-valg-$1.log | { read lines; test $$lines -eq 1 || cat /tmp/unit-test-valg-$1.log; }

memcheck:
	$(call build-dir, $@) && cmake .. -DCMAKE_BUILD_TYPE=Debug && $(MAKE)

memcheck-logging: memcheck
	cd memcheck-build && $(call memcheck-binary,logging_tests)

valgrind: memcheck-unit

dockerimage:
	cd dockerbuild && (docker images | grep $(BINARY)-deploy) || docker build -t $(BINARY)-deploy -f Dockerfile-deploy .

dockerimage-clean:
	docker rm $(shell docker ps -a -q) || true
	docker rmi $(shell docker images -a --filter=dangling=true -q) || true
	docker rmi $(BINARY)-deploy || true

dockerbuild/$(BINARY).tar.gz:
	rm -f dockerbuild/$(BINARY).tar.gz
	git archive --format=tar.gz -o dockerbuild/$(BINARY).tar.gz --prefix=$(BINARY)/ HEAD

stylecheck:
	 find src include test \( -name '*.cpp' -o -name '*.hpp' \) -exec \
		uncrustify -c uncrustify.cfg --check {} \;

stylefix:
	find src include test \( -name '*.cpp' -o -name '*.hpp' \) -exec \
		uncrustify -c uncrustify.cfg --replace {} \;

full-deploy: debug release clang clang-release static-release analyzed memcheck deploy deploy-ctoxcore asan asan-release tsan tsan-release

deploy: dockerbuild/$(BINARY).tar.gz
	cd dockerbuild && docker run -v "$(shell pwd)/dockerbuild:/mnt/host" $(BINARY)-deploy /bin/bash -c 'cd /root && tar xfz /mnt/host/$(BINARY).tar.gz && cd $(BINARY) && mkdir build && cd build && cmake -DSTATIC=True -DCMAKE_BUILD_TYPE=RelWithDebInfo .. && make $(BINARY) -j $(JOBS) && cp $(BINARY) /mnt/host/$(BINARY)'
	rm dockerbuild/$(BINARY).tar.gz

coverage:
	$(call build-dir, $@) &&  cmake .. -DCMAKE_BUILD_TYPE=Debug -DCOVERAGE=True && $(MAKE) coverage

dockerized-build: dockerbuild/$(BINARY).tar.gz
	cd dockerbuild && docker run -v "$(shell pwd)/dockerbuild:/mnt/host" $(BINARY) /bin/bash -c 'cd /root && tar xfz /mnt/host/$(BINARY).tar.gz && cd $(BINARY) && export LD_LIBRARY_PATH=/usr/lib/llvm-6.0/lib/ && export PATH=/usr/lib/llvm-6.0/bin:$$PATH && make'
	rm dockerbuild/$(BINARY).tar.gz

.PHONY: dockerbuild/$(BINARY).tar.gz
