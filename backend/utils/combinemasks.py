from typing import List, Optional, Union
import numpy as np
import cv2


def combine_bitmasks(
    mask_paths: List[str],
    output_path: Optional[str] = None
) -> Union[str, np.ndarray]:
    if not mask_paths:
        raise ValueError("mask_paths is empty")

    if len(mask_paths) == 1:
        single_mask = cv2.imread(mask_paths[0], cv2.IMREAD_GRAYSCALE)
        if single_mask is None:
            raise FileNotFoundError(f"Could not read mask: {mask_paths[0]}")

        _, single_mask_bin = cv2.threshold(single_mask, 0, 255, cv2.THRESH_BINARY)

        if output_path:
            cv2.imwrite(output_path, single_mask_bin)
            return output_path
        return single_mask_bin


    combined_mask = None

    for path in mask_paths:
        mask = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
        if mask is None:
            raise FileNotFoundError(f"Could not read mask: {path}")


        _, mask_bin = cv2.threshold(mask, 0, 255, cv2.THRESH_BINARY)

        if combined_mask is None:
            combined_mask = mask_bin.astype(np.uint8)
        else:

            combined_mask = cv2.bitwise_or(combined_mask, mask_bin)


    combined_mask = (combined_mask > 0).astype(np.uint8) * 255

    if output_path:
        cv2.imwrite(output_path, combined_mask)
        return output_path

    return combined_mask