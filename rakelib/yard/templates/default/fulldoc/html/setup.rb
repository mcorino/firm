# frozen_string_literal: true

def init
  # It seems YARD messes things up so that a lot of classes, modules and constants are not properly
  # registered in their enclosing namespaces.
  # This hack makes sure that if that is the case we fix that here.
  all_objects = Registry.all(:class, :constant, :module, :method)
  all_objects.each do |c|
    if (ns = c.namespace)
      unless ns.children.any? { |nsc| nsc.path == c.path }
        ns.children << c # class/module/constant/method missing from child list of enclosing namespace -> add here
      end
    end
    if (ns = Registry[c.namespace.path])
      unless ns.children.any? { |nsc| nsc.path == c.path }
        ns.children << c # class/module/constant/method missing from child list of enclosing namespace -> add here
      end
    end
  end
  super
end

def stylesheets_full_list
  super + %w(css/firm.css)
end
