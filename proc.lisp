(in-package :js)

(defun traverse-form (form)
  (cond ((null form) nil)
	((atom form)
	 (if (keywordp form)
	     (js-intern form) form))
	(t
	 (case (car form)
	   ((:var)
		  (cons (js-intern (car form))
				(list (mapcar
					   (lambda (var-desc)
						 (let ((var-sym (->sym (car var-desc))))
						   (queue-enqueue env var-sym)
						   (queue-enqueue locals var-sym)
						   (cons (->sym (car var-desc))
								 (traverse-form (cdr var-desc)))))
					   (second form)))))
	   ((:name) (list (js-intern (car form)) (->sym (second form))))
	   ((:dot) (list (js-intern (car form)) (traverse-form (second form))
					 (->sym (third form))))
	   ((:function :defun)
	      (when (and (eq (car form) :defun)
			 (second form))
		(let ((fun-name (->sym (second form))))
		  (queue-enqueue env fun-name)
		  (queue-enqueue locals fun-name)))
	      (let ((placeholder (list (car form))))
		(queue-enqueue lmbd-forms (list form env placeholder))
		placeholder))
	   (t (mapcar #'traverse-form form))))))

(defun shallow-process-toplevel-form (form)
  (let ((env (queue-make))
		(locals (queue-make)))
    (declare (special env locals))
    (traverse-form form)))

(defun lift-defuns (form)
  (let (defuns oth)
    (loop for el in form do
      (if (eq (car el) :defun) (push el defuns)
	  (push el oth)))
    (format t ">>>>>>>>>>>defuns: ~A ~A~%" (reverse defuns) (reverse oth))
    (append (reverse defuns) (reverse oth))))

(defun shallow-process-function-form (form old-env)
  (let* ((env (queue-copy old-env))
		 (locals (queue-make))
		 (arglist (mapcar #'->sym (third form)))
		 (new-form (traverse-form (fourth form)))
		 (name (and (second form) (->sym (second form)))))
    (declare (special env locals))
    (mapc (lambda (arg) (queue-enqueue env arg)) arglist)
    (list (js-intern (first form))
		  (if name (cons name (cdr (queue-list old-env)))
			  (cdr (queue-list old-env)))
		  name arglist (cdr (queue-list locals)) (lift-defuns new-form))))

(defun process-ast (ast)
  (assert (eq :toplevel (car ast)))
  (let ((lmbd-forms (queue-make)))
    (declare (special lmbd-forms))
    (let ((toplevel (shallow-process-toplevel-form ast)))
      (loop until (queue-empty? lmbd-forms)
	    for (form env position) = (queue-dequeue lmbd-forms) do
	      (let ((funct-form (shallow-process-function-form form env)))
		(setf (car position) (car funct-form)
		      (cdr position) (cdr funct-form))))
      toplevel)))
