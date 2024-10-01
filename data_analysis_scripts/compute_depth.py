import cv2
import numpy as np

def split_frame(frame):
    height, width = frame.shape[:2]
    mid = width // 2
    left_frame = frame[:, :mid]
    right_frame = frame[:, mid:]
    return left_frame, right_frame

def compute_depth_map(left_image, right_image, stereo):
    # Convert to grayscale
    left_gray = cv2.cvtColor(left_image, cv2.COLOR_BGR2GRAY)
    right_gray = cv2.cvtColor(right_image, cv2.COLOR_BGR2GRAY)
    
    # Compute disparity map
    disparity = stereo.compute(left_gray, right_gray).astype(np.float32) / 16.0
    
    # Apply a bilateral filter to reduce noise and preserve edges
    disparity_filtered = cv2.bilateralFilter(disparity, 5, 75, 75)
    
    # Normalize disparity for visualization (optional, can be skipped if raw disparity is needed)
    disparity_normalized = cv2.normalize(disparity_filtered, None, 0, 255, cv2.NORM_MINMAX)
    return disparity_normalized.astype(np.uint8)

def temporal_smoothing(prev_depth_map, current_depth_map, alpha=0.9):
    # Apply exponential moving average for temporal smoothing
    if prev_depth_map is None:
        return current_depth_map
    else:
        smoothed_depth_map = cv2.addWeighted(current_depth_map, alpha, prev_depth_map, 1 - alpha, 0)
        return smoothed_depth_map

def process_video(input_path, output_path):
    cap = cv2.VideoCapture(input_path)
    
    # Get video properties
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    # Create VideoWriter object
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width // 2, height), isColor=False)
    
    # StereoSGBM initialization with tuned parameters
    num_disparities = 64  # A multiple of 16, increase for higher disparity range
    block_size = 11  # Increased block size to reduce noise in low-texture regions
    
    stereo = cv2.StereoSGBM_create(
        minDisparity=0,
        numDisparities=num_disparities,
        blockSize=block_size,
        P1=8 * 3 * block_size**2,
        P2=32 * 3 * block_size**2,
        disp12MaxDiff=1,
        uniquenessRatio=10,
        speckleWindowSize=100,
        speckleRange=32,
        preFilterCap=63,
        mode=cv2.STEREO_SGBM_MODE_SGBM_3WAY
    )
    
    prev_depth_map = None
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        left_frame, right_frame = split_frame(frame)
        current_depth_map = compute_depth_map(left_frame, right_frame, stereo)
        
        # Apply temporal smoothing to reduce flickering
        smoothed_depth_map = temporal_smoothing(prev_depth_map, current_depth_map)
        prev_depth_map = smoothed_depth_map
        
        out.write(smoothed_depth_map)
        
        # Optional: display the depth map (comment out for faster processing)
        # cv2.imshow('Depth Map', smoothed_depth_map)
        # if cv2.waitKey(1) & 0xFF == ord('q'):
        #     break
    
    cap.release()
    out.release()
    cv2.destroyAllWindows()

# Usage
input_video_path = "IMG_0110_SBS_SBS.mov"


output_video_path = 'output_depth_map_smoothed_IMG_0110_SBS_SBS.mp4'
process_video(input_video_path, output_video_path)
