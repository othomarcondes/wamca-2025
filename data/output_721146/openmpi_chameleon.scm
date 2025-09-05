(use-modules (guix transformations)
	     (inria storm)
	     (ufrgs ufrgs)
             (guix-hpc packages solverstack)
             (gnu packages pretty-print)
             (guix packages))

(packages->manifest
  (list (specification->package "chameleon@1.3.0")
	(specification->package "starpu-fxt")
	(specification->package "openmpi@4")
	(specification->package "gcc-toolchain@14")
	(specification->package "pageng")))
