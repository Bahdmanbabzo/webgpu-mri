import tensorflow as tf
import os

IMG_WIDTH = 256
IMG_HEIGHT = 256

def load_image_pair(original_path, edge_path):
    """
    Loads and preprocesses a pair of images (original and edge-detected) from the given file paths.
    The function reads each image file, decodes it as a grayscale PNG, resizes it to the dimensions
    specified by IMG_HEIGHT and IMG_WIDTH, and normalizes the pixel values to the range [0, 1].
    Args:
        original_path (str): File path to the original image.
        edge_path (str): File path to the edge-detected image.
    Returns:
        tuple: A tuple containing two TensorFlow tensors:
            - original_image (tf.Tensor): The preprocessed original image tensor of shape (IMG_HEIGHT, IMG_WIDTH, 1).
            - edge_image (tf.Tensor): The preprocessed edge-detected image tensor of shape (IMG_HEIGHT, IMG_WIDTH, 1).
    """

    original_image = tf.io.read_file(original_path)
    original_image = tf.image.decode_png(original_image, channels=1)
    original_image = tf.image.resize(original_image, [IMG_HEIGHT, IMG_WIDTH])
    original_image = tf.cast(original_image, tf.float32) / 255.0

    edge_image = tf.io.read_file(edge_path)
    edge_image = tf.image.decode_png(edge_image, channels=1)
    edge_image = tf.image.resize(edge_image, [IMG_HEIGHT, IMG_WIDTH])
    edge_image = tf.cast(edge_image, tf.float32) / 255.0

    return original_image, edge_image

def augment(original_image, edge_image):
    """
    Applies random data augmentation to a pair of images (original and edge-detected).
    The function randomly flips the images horizontally and/or vertically with a 50% chance for each.
    Args:
        original_image (tf.Tensor): The original image tensor.
        edge_image (tf.Tensor): The edge-detected image tensor.
    Returns:
        tuple: A tuple containing two TensorFlow tensors:
            - augmented_original (tf.Tensor): The augmented original image tensor.
            - augmented_edge (tf.Tensor): The augmented edge-detected image tensor.
    """

    if tf.random.uniform(()) > 0.5:
        original_image = tf.image.flip_left_right(original_image)
        edge_image = tf.image.flip_left_right(edge_image)

    if tf.random.uniform(()) > 0.5:
        original_image = tf.image.flip_up_down(original_image)
        edge_image = tf.image.flip_up_down(edge_image)

    return original_image, edge_image

def get_dataset(originals_dir, edges_dir, batch_size=8):
    """
    Creates a TensorFlow dataset for paired image data, typically used for supervised learning tasks such as image-to-image translation.
    Args:
        originals_dir (str): Path to the directory containing original images (input images).
        edges_dir (str): Path to the directory containing edge images (target images).
        batch_size (int, optional): Number of image pairs per batch. Defaults to 8.
    Returns:
        tf.data.Dataset: A TensorFlow dataset yielding batches of (original_image, edge_image) pairs, preprocessed and augmented.
    Notes:
        - Assumes that both directories contain the same number of PNG files, with matching filenames.
        - Issues a warning if the number of files in the two directories does not match.
        - Applies image loading, resizing, and augmentation to the dataset.
        - Prefetches batches for improved performance.
    """

    # Check that file counts match to avoid "silent errors"
    orig_len = len(os.listdir(originals_dir))
    edge_len = len(os.listdir(edges_dir))
    if orig_len != edge_len:
        print(f"WARNING: Found {orig_len} originals and {edge_len} edges. Mismatch!")

    original_files = sorted([os.path.join(originals_dir, f) for f in os.listdir(originals_dir) if f.endswith('.png')])
    edge_files = sorted([os.path.join(edges_dir, f) for f in os.listdir(edges_dir) if f.endswith('.png')])

    dataset = tf.data.Dataset.from_tensor_slices((original_files, edge_files))
    
    # Load and Resize
    dataset = dataset.map(load_image_pair, num_parallel_calls=tf.data.AUTOTUNE)
    
    # Augment (only for training data!)
    dataset = dataset.map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    
    dataset = dataset.batch(batch_size)
    dataset = dataset.prefetch(tf.data.AUTOTUNE)
    print(f"Dataset created with {len(original_files)} image pairs.")
    return dataset

print(get_dataset('public/train/originals', 'public/train/edges', batch_size=8))