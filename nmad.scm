(use-modules (guix transformations)
	     (inria storm)
	     (ufrgs ufrgs)
             (guix-hpc packages solverstack)
             (gnu packages pretty-print)
             (guix packages))

(define transform1
  (options->transformation
    '((with-commit . "nmad=6e1a64d0")
      (with-commit . "pioman=6e1a64d0")
      (with-commit . "padicotm=6e1a64d0")
      (with-commit . "puk=6e1a64d0")
      (with-input . "starpu=starpu-fxt")
      (with-input . "openmpi=nmad"))))

(packages->manifest
  (list (transform1 (specification->package "guix"))
        (transform1 (specification->package "nmad"))
        (transform1
          (specification->package "gcc-toolchain"))
	(transform1 (specification->package "chameleon@1.3.0"))
	(transform1 (specification->package "starpu-fxt@1.4.8"))
	(transform1 (specification->package "pageng"))))
