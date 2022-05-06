class_name BaseCel
extends Reference
# Base class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var opacity: float

# Each Cel type should have a get_image function, which will either return
# its image data for PixelCels, or return a render of that cel. It's meant
# for read-only usage of image data from any type of cel
