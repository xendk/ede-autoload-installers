;;; ede-autoload-installers.el --- Composer installers support for ede-php-autoload  -*- lexical-binding: t; -*-

;; Copyright (C) 2017  Thomas Fini Hansen

;; Author: Thomas Fini Hansen <xen@xen.dk>
;; Created: January 29, 2017
;; Version: 0.1.0
;; Package-Requires: ((ede-php-autoload "20170123.1113") (f "0.19.0") (s "1.7.0"))
;; Keywords: programming, php

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(require 'ede-php-autoload)
(require 'f)
(require 's)

(defun ede-autoload-installers-autoloads (context autoloads)
  "Visitor that fixes composer installers autoloads.

CONTEXT is the composer context and AUTOLOADS are the currently
found autoloads."
  (let* ((composer-data (ede-php-autoload-composer-get-composer-data context))
         ;; Don't know if require-dev'ing composer/installers makes
         ;; any sense, but we'll check for it anyway.
         (requires (append (cdr (assoc 'require composer-data))
                           (cdr (assoc 'require-dev composer-data)))))
    (if (assoc 'composer/installers requires)
        (let* ((composer-lock (ede-php-autoload-composer-get-composer-lock context))
               (project-dir (ede-php-autoload-composer-get-project-dir context))
               (extra (cdr (assoc 'extra composer-data)))
               (installer-paths (ede-autoload-installers--flip-installer-paths (cdr (assoc 'installer-paths extra))))
               (packages (ede-php-autoload-composer--get-third-party-data composer-lock))
               (i 0)
               (l (length packages))
               current-data)
          (while (< i l)
            (setq current-data (aref packages i)
                  autoloads (ede-php-autoload--merge-composer-autoloads
                             current-data
                             autoloads
                             (ede-autoload-installers--get-package-dir current-data installer-paths project-dir))
                  i (1+ i))
            )
          autoloads)
      (autoloads))))

(defun ede-autoload-installers--get-package-dir (package-data installer-paths project-dir)
  "Return the directory that contain third party sources.

PACKAGE-DATA is the data for the corresponding third-party in the
composer.lock file.

INSTALLER-PATHS is the flipped installer-paths configuration from the
extra section of the composer.json.

PROJECT-DIR is the project root."
  (let* ((package (cdr (assoc 'name package-data)))
         (type (or (cdr (assoc 'type package-data)) "library"))
         (tmp (split-string package "\\/"))
         (vendor (car tmp))
         (name (cadr tmp))
         (paths (delete nil (list
                             (assoc package installer-paths)
                             (assoc (concat "type:" type) installer-paths)
                             (assoc (concat "vendor:" vendor) installer-paths)))))
    (if (> (length paths) 0)
        (let* ((path (s-replace "{$name}" name
                               (s-replace "{$vendor}" vendor
                                          (s-replace "{$type}" type
                                                     (symbol-name (cdr (car paths))))))))
          (f-join project-dir path))
      (if (equal  "library" type)
          (f-join project-dir "vendor" package)
        (user-error "Unknown package type '%s'" type)))))

(defun ede-autoload-installers--flip-installer-paths (installer-paths)
  "Flips INSTALLER-PATHS into a lookup table."
  (cl-loop for (key . value) in installer-paths
           ;; The append coverts the vector to a list.
           append (cl-loop for spec in (append value nil)
                           collect (cons spec key))))

(ede-php-autoload-composer-define-visitor #'ede-autoload-installers-autoloads)
;; (add-to-list 'ede-php-autoload-composer--visitors #'ede-autoload-installers-autoloads t)

(provide 'ede-autoload-installers)
;;; ede-autoload-installers.el ends here