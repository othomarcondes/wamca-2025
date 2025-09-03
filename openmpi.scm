(use-modules (guix transformations)
	     (inria storm)
	     (ufrgs ufrgs)
             (guix-hpc packages solverstack)
             (gnu packages pretty-print)
             (guix packages))

(packages->manifest
  (list (specification->package "guix")
        (specification->package "gcc-toolchain")
	(specification->package "openmpi@5.0.7")
	(specification->package "chameleon@1.3.0")
	(specification->package "starpu-fxt@1.4.8")
	(specification->package "pageng")))
