(defpackage #:weblocks/page
  (:use #:cl)
  (:import-from #:weblocks/variables
                #:*default-content-type*)
  (:import-from #:weblocks/html
                #:*lang*
                #:with-html
                #:get-rendered-chunk)
  (:import-from #:weblocks/dependencies
                #:render-in-head
                #:get-dependencies
                #:register-dependencies
                #:get-collected-dependencies)
  (:import-from #:weblocks/app
                #:app)
  (:import-from #:alexandria
                #:symbolicate)


  ;;user-routes
  (:import-from #:weblocks/user-routes
		#:get-page)

  ;; Just dependencies
  (:import-from #:log)

  (:export
   #:define-page
   #:render
   #:render-body
   #:render-dependencies
   #:render-headers
   #:get-title
   #:get-description
   #:get-keywords
   #:get-language
   #:with-layout
   #:with-head))
(in-package weblocks/page)


(defvar *title* nil)
(defvar *description* nil)
(defvar *keywords* nil)
(defvar *language* "en")


(weblocks/widget:defwidget page ()
    ((page-head :initform NIL :initarg :page-head :accessor page-head)
     (page-body :initform NIL :initarg :page-body :accessor page-body)))

(defmacro define-page (page-name page-head page-body other-slots)
  (let ((make-func-name (alexandria:symbolicate :make- page-name)))
    `(progn
       (weblocks/widget:defwidget ,page-name (page)
	 ,other-slots)
       (defun ,make-func-name ()
	 (make-instance ',page-name
			:page-head ,page-head
			:page-body ,page-body)))))

(defmacro def-get-set (variable)
  "Generates a function get-<variable> and a corresponding setf part."
  (let ((func-name (symbolicate :get- variable))
        (var-name (symbolicate :* variable :*)))
    `(progn
       (defun ,func-name ()
         ,var-name)

       (defun (setf ,func-name) (value)
         (setf ,var-name value)))))


(def-get-set title)
(def-get-set description)
(def-get-set keywords)
(def-get-set language)


(defmethod render-headers ((app app))
  "A placeholder to add :meta entries, :expires headers and other
   header content on a per-webapp basis.  For example, using a dynamic
   hook on rendering you can bind special variables that are dereferenced
   here to customize header rendering on a per-request basis.  By default
   this function renders the current content type."
  (with-html
    (:meta :http-equiv "Content-type"
           :content *default-content-type*)

    (when (get-description)
      (:meta :name "description"
             :content (get-description)))
    (when (get-keywords)
      (:meta :name "keywords"
             :content (format nil "~{~A~^,~}" (get-keywords))))

    ;; Headers aren't tags but any code snippets or functions
    ;; returning strings.
    ;; (dolist (header *current-page-headers*)
    ;;   (etypecase header
    ;;     (string (htm (str header)))
    ;;     ;; TODO: Right now (old code) expects that function will write
    ;;     ;; to special stream, but we need to make it return a value
    ;;     ;; to be consistent with string headers.
    ;;     ((or function symbol) (funcall header))))
    ))


(defmethod render-body ((app app) body-string)
  "Default page-body rendering method"

  (with-html
    (:raw body-string)))


(defmethod render-dependencies ((app app) dependencies)
  (etypecase dependencies
    (list (mapc #'render-in-head
                 dependencies))
    (string (with-html
              (:raw dependencies)))))


(defmethod render ((app app)
                   inner-html
                   &key (dependencies (get-dependencies app)))
  "Default page rendering template and protocol."
  (log:debug "Rendering page for" app)

  (register-dependencies dependencies)

  (let ((*lang* (get-language)))
    (with-html
      (:doctype)
      (:html
       (:head
        (:title (get-title))

        ;; It is XXI century, you know?
        ;; All sites should be optimized for mobile screens
        (:meta :name "viewport"
               :content "width=device-width, initial-scale=1")

        (render-headers app)
        (render-dependencies app dependencies))
       (:body
        (render-body app inner-html)
        ;; (:script :type "text/javascript"
        ;;          "updateWidgetStateFromHash();")
        )))))


(defmethod render-page-with-widgets ((app app))
  "Renders a full HTML by collecting header elements, dependencies and inner
   HTML and inserting them into the `render' method."
  (log:debug "Special Rendering page for" app)

  ;; At the moment when this method is called, there is already
  ;; rendered page's content in the weblocks/html::*stream*.
  ;; All we need to do now – is to render dependencies in the header
  ;; and paste content into the body.
  (let* ((rendered-html (get-rendered-chunk))
         (all-dependencies (get-collected-dependencies)))
    (render app rendered-html :dependencies all-dependencies)))

(defun render-page-with-widgets-test (root-widget)
  "Renders a full HTML by collecting header elements, dependencies and inner
   HTML and inserting them into the `render' method."
  (log:debug "Special Rendering page for" root-widget)

  ;; At the moment when this method is called, there is already
  ;; rendered page's content in the weblocks/html::*stream*.
  ;; All we need to do now – is to render dependencies in the header
  ;; and paste content into the body.
    (render-page-test (get-page root-widget) :dependencies (get-collected-dependencies)))

(defmacro with-head (page-head)
  `(with-html
     (:meta :http-equiv "Content-type"
            :content "*default-content-type*")

     (when T
       (:meta :name "description"
              :content "(get-description)"))
     (when T
       (:meta :name "keywords"
              :content "(format nil \"~{~A~^,~}\" (get-keywords))"))
     ;; (:title "home")
     ,@page-head
     ;; Headers aren't tags but any code snippets or functions
     ;; returning strings.
     ;; (dolist (header *current-page-headers*)
     ;;   (etypecase header
     ;;     (string (htm (str header)))
     ;;     ;; TODO: Right now (old code) expects that function will write
     ;;     ;; to special stream, but we need to make it return a value
     ;;     ;; to be consistent with string headers.
     ;;     ((or function symbol) (funcall header))))
     ))

(defun render-headers-test (page-head)
  "A placeholder to add :meta entries, :expires headers and other
   header content on a per-webapp basis.  For example, using a dynamic
   hook on rendering you can bind special variables that are dereferenced
   here to customize header rendering on a per-request basis.  By default
   this function renders the current content type."
  (if page-head
      page-head
      (with-html
	(:meta :http-equiv "Content-type"
               :content *default-content-type*)

	(when (get-description)
	  (:meta :name "description"
		 :content (get-description)))
	(when (get-keywords)
	  (:meta :name "keywords"
		 :content (format nil "~{~A~^,~}" (get-keywords))))
	;; (:title "home")
	(when page-head
	  (format nil "~{~A~^,~}" page-head))
	;; Headers aren't tags but any code snippets or functions
	;; returning strings.
	;; (dolist (header *current-page-headers*)
	;;   (etypecase header
	;;     (string (htm (str header)))
	;;     ;; TODO: Right now (old code) expects that function will write
	;;     ;; to special stream, but we need to make it return a value
	;;     ;; to be consistent with string headers.
	;;     ((or function symbol) (funcall header))))
	)))

(defun render-dependencies-test (dependencies)
  (etypecase dependencies
    (list (mapc #'render-in-head
                 dependencies))
    (string (with-html
              (:raw dependencies)))))

(defun render-body-test (page-body)
  (when page-body
   (weblocks/widget:render page-body)))

(defun render-page-test (page &key dependencies)
  "A test method to render page with user defined page-head and page-body"
  (log:debug "Special Rendering page test for page" page)
  (register-dependencies dependencies)
  (let ((*lang* (get-language)))
    (with-html
      (:doctype)
      (:html
       (:head
        ;; (:title (get-title))

        ;; It is XXI century, you know?
        ;; All sites should be optimized for mobile screens
        (:meta :name "viewport"
               :content "width=device-width, initial-scale=1")

        (render-headers-test (page-head page))
        (render-dependencies-test dependencies))
       (:body
        (render-body-test (page-body page))
        ;; (:script :type "text/javascript"
        ;;          "updateWidgetStateFromHash();")
        )))))
