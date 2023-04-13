- MClass
    - meta slots
    - downside of classes being also instances, are not represented in the same way as the latter
    - get and set property
- MMultiMethod, MGenericFunction
    - all standard stuff

- bootstrapping initial classes
    - Top, Object, Class, all done by hand
    - collect(fieldnames(Struct)) is a nice thing to have when making changes

- bootstrapping the system
    - _compute_cpl
    - _compute_slots
    - _compute_defaulted
    - _compute_meta_slots
        - Class edge case
    - _compute_getter
    - _compute_setter

    - _new_default_class, new class without using any protocols or generic functions 
    - now we can build _Int64 and _String

- new(), relate it with Class

- define class_of for everyone
- define other getters of class_...
- method_specializers and generic_methods
- _add_method()
- defgeneric add(x, y) to _add_method example
- defmethod to defgeneric + _add_method example
- multiple dispatch
    - specificity

- Protocols
    - compute_cpl = _compute_cpl
    - compute_slots = _compute_slots
    - compute_getter_and_setter = (_compute_getter(slot), _compute_setter(slot))

    - allocate_instance
        - edge case of Class
    - initialize
    - new function

- print_object
- _new_class and @defclass
