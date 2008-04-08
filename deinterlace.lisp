(in-package :png-read)

(defvar *adam7* #2A((1 6 4 6 2 6 4 6)
		    (7 7 7 7 7 7 7 7)
		    (5 6 5 6 5 6 5 6)
		    (7 7 7 7 7 7 7 7)
		    (3 6 4 6 3 6 4 6)
		    (7 7 7 7 7 7 7 7)
		    (5 6 5 6 5 6 5 6)
		    (7 7 7 7 7 7 7 7)))

(defun make-interlace-pass-array (w h)
  (let ((i-array (make-array (list w h) :initial-element 0)))
    (dotimes (x w i-array)
      (dotimes (y h)
	(setf (aref i-array x y)
	      (aref *adam7* (mod y 8) (mod x 8)))))))

(defun make-deinterlace-arrays (pass-array)
  (let ((leaves (make-array 7 :initial-element nil)))
   (destructuring-bind (w h) (array-dimensions pass-array)
     (dotimes (x w (map 'vector #'nreverse leaves))
       (dotimes (y h)
	 (push (list x y) (aref leaves (1- (aref pass-array x y)))))))))

(defun get-height-passlist (pass-list)
  (let ((init-x (caar pass-list)))
    (iter (for d in pass-list)
	  (while (eql init-x (car d)))
	  (summing 1))))

(defun split-datastream (datastream bd sub-widths sub-heights)
  (let ((ctr 0))
   (iter (for w in sub-widths)
	 (for h in sub-heights)
	 (let ((end-ctr (+ ctr h (ceiling (* w h bd) 8))))
	   (collect (subseq datastream ctr end-ctr))
	   (setf ctr end-ctr)))))

(defun decode-subimages (data png-state)
  (let ((w (width png-state))
	(h (height png-state)))
    (let ((sub-array (make-deinterlace-arrays (make-interlace-pass-array w h))))
     (let ((sub-heights (map 'list #'get-width-passlist sub-array)))
       (let ((sub-widths (map 'list #'(lambda (lt wi)
					(/ (length lt) wi))
			      sub-array sub-heights)))
	 (let ((datastreams (split-datastream data
					      (bit-depth png-state)
					      sub-widths
					      sub-heights)))
	   (iter (for i from 0 below 7)
		 (for w in sub-widths)
		 (for h in sub-heights)
		 (for datastream in datastreams)
		 (setf (width png-state) w
		       (height png-state) h)
		 (decode-data (colour-type png-state) datastream png-state)
		 (collect (image-data png-state)))))))))

(defun decode-interlaced (data png-state)
  (let ((sub-images (decode-subimages data png-state)))
    (setf (image-data png-state) sub-images)))