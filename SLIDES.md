# Class
To start the system we need to be able to talk about classes.
We chose to represent classes with a special struct type (this will cause some problems later, because classes and instances will not be represented in a uniform way).

This struct has the necessary fields to support multiple superclasses, slots, getters and setter. Additionally, it has a field to store the slots from its metaclass which is empty for most classes since their metaclass is Class.

Now, we just need to define Base.getproperty and Base.setproperty to access the slots of a class. This needs to be done precisely because classes can have slots specified by their metaclass. The getter and setter will always try to access the fields of the class struct first and then will fallback to the metaclass slots.

# Instances
Next, we need to able to talk about instances. We represent instances with a special struct type as well. This struct has a field for storing the class of the instance and a field for storing the slots specified by its class.

We also need to define Base.getproperty and Base.setproperty to access the slots of an instance. The getter and setter will get the `slots` dictionary from the instance and then check whether the request slot is in the dictionary. If it is, it will return the value, otherwise it will cause an error.

Note that this function will call the getter / setter of the class of the instance. This will allow us to implement the Slot Access Protocol later.

# Bootstrapping the Initial Base Classes
The initial classes of the system will have to be defined by hand. Since there's circularity in the definition of these base classes, we have to define them first and, only after that, we are able to connect them by filling the missing fields. One nice thing about this piece of code is the `collect(fieldnames())`
which is a nice way to get the names of the fields of a struct. This way, we can easily change the fields of the `MClass` struct and the class `Class` will still be defined correctly.

# Bootstrapping the remaining Classes
We can now define some helper functions to compute necessary fields for the classes. Some of these functions will later be used to define the default behavior of the protocols of the system.

Now we're able to define the remaining classes of the system. Note that the function `_new_default_class` is used to define the classes without using any protocols or generic functions under the hood.

We can also define some helper functions like `class_of`, `class_name`, `class_cpl`, `class_slots`, `class_direct_slots` and `class_direct_superclasses`.

# MMultiMethod, MGenericFunction
We also need to be able to talk about methods and generic functions. These are represented by structs as well. Methods have a field for storing their specializers and generic functions store a list of their methods.

We can define some helper functions like `method_specializers` and `generic_methods`. Additionally, we can define a function to add a method to a generic function: `_add_method`. This function will check whether the method already exists and, if it does, it will replace it. Otherwise it will just add it to the list of methods.

We are now able the `@defgeneric` macro to define generic functions and the `@defmethod` macro to define methods. We will use them to define the Jos' own generic functions and methods. One important thing to note is that the `@defmethod` macro will add an extra argument to the method call: the `call_next_method` function. This function will be used to call the next method in the list of the methods of the generic function.

# Multiple Dispatch
In order for our generic functions to work, we need to be able to dispatch methods. Firstly we can define the generic function `no_applicable_method` which will be called when no method is applicable to the arguments.

Then we need to specialize the function call on the `MGenericFunction` type. Calling an instance of this type will filter the applicable methods and sort them by specificity. Then it will call the first method in the list. An inner `call_next_method` function will be passed to the method call, so that it can keep track of the next method to call. 

# Protocols
To implement protocols, we need to expose some the already implemented behavior of the system through generic functions. 

For the Class Instantiation Protocol, we start to feel the limitations of the current implementation. Since the system doesn't use a uniform representation for classes and instances, we need to define a special case for the `Class` class which restricts the user to only instantiate classes of the meta-class `Class`. This is not a problem for the current implementation, since the `@defmacro` macro will not make use of the Class Instantiation Protocol thus avoiding this problem.

Then, we just need to specialize the `initialize` generic function for each class. Note that, when defining the `initialize` method for the `Class` class, we need to call the `compute_cpl` and `compute_slots` generic functions in order to actually implement those protocols.

With this done our `new` function is ready to be used.

# Printing Stuff
For printing the objects of the system, we need define a generic function `print_object` and specialize it for the different classes. We also need to specialize Julia's `show` function to call the `print_object` generic function.

# The @defclass Macro
Finally, we can define the `@defclass` macro which will call the `_new_class()` function to create a new class. Similarly to what is done in the `new()` function, the `_new_class()` function will the necessary generic functions to implement the protocols of the system.

# Final Remarks
Not having a uniform representation for classes and instances is a problem for the current implementation. For example, some of the protocols such as the Slot Access Protocol are not implement for classes. On the other hand, it can also be argued that this implementation is more efficient since it avoids having to store all the slots of the class in a dictionary.
